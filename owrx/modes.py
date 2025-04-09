from owrx.feature import FeatureDetector
from owrx.audio import ProfileSource
from functools import reduce
from abc import ABCMeta, abstractmethod


class Bandpass(object):
    def __init__(self, low_cut, high_cut):
        self.low_cut = low_cut
        self.high_cut = high_cut


class Mode:
    def __init__(self, modulation: str, name: str, bandpass: Bandpass = None, requirements=None, service=False, squelch=True):
        self.modulation = modulation
        self.name = name
        self.requirements = requirements if requirements is not None else []
        self.service = service
        self.bandpass = bandpass
        self.squelch = squelch

    def is_available(self):
        fd = FeatureDetector()
        return reduce(lambda a, b: a and b, [fd.is_available(r) for r in self.requirements], True)

    def is_service(self):
        return self.service

    def get_bandpass(self):
        return self.bandpass

    def get_modulation(self):
        return self.modulation


EmptyMode = Mode("empty", "Empty")


class AnalogMode(Mode):
    pass


class DigitalMode(Mode):
    def __init__(
        self,
        modulation,
        name,
        underlying,
        bandpass: Bandpass = None,
        requirements=None,
        service=False,
        squelch=True,
        secondaryFft=True
    ):
        super().__init__(modulation, name, bandpass, requirements, service, squelch)
        self.underlying = underlying
        self.secondaryFft = secondaryFft

    def get_underlying_mode(self):
        mode = Modes.findByModulation(self.underlying[0])
        if mode is None:
            mode = EmptyMode
        return mode

    def get_bandpass(self):
        if self.bandpass is not None:
            return self.bandpass
        return self.get_underlying_mode().get_bandpass()

    def get_modulation(self):
        return self.get_underlying_mode().get_modulation()

    def for_underlying(self, underlying: str):
        if underlying not in self.underlying:
            raise ValueError("{} is not a valid underlying mode for {}".format(underlying, self.modulation))
        return DigitalMode(
            self.modulation, self.name, [underlying], self.bandpass, self.requirements, self.service, self.squelch
        )


class AudioChopperMode(DigitalMode, metaclass=ABCMeta):
    def __init__(self, modulation, name, bandpass=None, requirements=None):
        if bandpass is None:
            bandpass = Bandpass(0, 3000)
        super().__init__(modulation, name, ["usb"], bandpass=bandpass, requirements=requirements, service=True)

    @abstractmethod
    def get_profile_source(self) -> ProfileSource:
        pass


class WsjtMode(AudioChopperMode):
    def __init__(self, modulation, name, bandpass=None, requirements=None):
        if requirements is None:
            requirements = ["wsjt-x"]
        super().__init__(modulation, name, bandpass=bandpass, requirements=requirements)

    def get_profile_source(self) -> ProfileSource:
        # inline import due to circular dependencies
        from owrx.wsjt import WsjtProfiles
        return WsjtProfiles.getSource(self.modulation)


class Js8Mode(AudioChopperMode):
    def __init__(self, modulation, name, bandpass=None, requirements=None):
        if requirements is None:
            requirements = ["js8call"]
        super().__init__(modulation, name, bandpass, requirements)

    def get_profile_source(self) -> ProfileSource:
        # inline import due to circular dependencies
        from owrx.js8 import Js8ProfileSource
        return Js8ProfileSource()


class Modes(object):
    mappings = [
        AnalogMode("nfm", "FM", bandpass=Bandpass(-4000, 4000)),
        AnalogMode("wfm", "WFM", bandpass=Bandpass(-75000, 75000)),
        AnalogMode("am", "AM", bandpass=Bandpass(-4000, 4000)),
        AnalogMode("lsb", "LSB", bandpass=Bandpass(-3000, -300)),
        AnalogMode("usb", "USB", bandpass=Bandpass(300, 3000)),
        AnalogMode("cw", "CW", bandpass=Bandpass(700, 900)),
        AnalogMode("sam", "SAM", bandpass=Bandpass(-4000, 4000)),
        AnalogMode("dmr", "DMR", bandpass=Bandpass(-6250, 6250), requirements=["digital_voice_digiham"], squelch=False),
		AnalogMode("m17", "DMR+", bandpass=Bandpass(-4000, 4000), requirements=["digital_voice_m17"], squelch=False),

        DigitalMode("bpsk31", "BPSK31", underlying=["usb"]),
        DigitalMode("bpsk63", "BPSK63", underlying=["usb"]),
        DigitalMode("rtty170", "RTTY-170 (45)", underlying=["usb", "lsb"]),
        DigitalMode("rtty450", "RTTY-450 (50N)", underlying=["usb", "lsb"]),
        DigitalMode("rtty85", "RTTY-85 (50N)", underlying=["usb", "lsb"]),
        DigitalMode("sitorb", "SITOR-B", underlying=["usb"]),
        WsjtMode("ft8", "FT8"),
        WsjtMode("ft4", "FT4"),
        WsjtMode("jt65", "JT65"),
        WsjtMode("jt9", "JT9"),
        WsjtMode("wspr", "WSPR", bandpass=Bandpass(1350, 1650)),
        WsjtMode("fst4", "FST4", requirements=["wsjt-x-2-3"]),
        WsjtMode("fst4w", "FST4W", bandpass=Bandpass(1350, 1650), requirements=["wsjt-x-2-3"]),
        WsjtMode("q65", "Q65", requirements=["wsjt-x-2-4"]),
        DigitalMode("msk144", "MSK144", requirements=["msk144"], underlying=["usb"], service=True),
        Js8Mode("js8", "JS8Call"),
        DigitalMode(
            "packet",
            "Packet",
            underlying=["empty"], #["nfm", "usb", "lsb"],
            bandpass=Bandpass(-6250, 6250),
            requirements=["packet"],
            service=True,
            squelch=False,
        ),
        DigitalMode(
            "ais",
            "AIS",
            underlying=["empty"], #["nfm"],
            bandpass=Bandpass(-6250, 6250),
            requirements=["packet"],
            service=True,
            squelch=False,
        ),
# Replaced by the general paging decoder (both POCSAG and FLEX)
#        DigitalMode(
#            "pocsag",
#            "Pocsag",
#            underlying=["nfm"],
#            bandpass=Bandpass(-6000, 6000),
#            requirements=["pocsag"],
#            service=True,
#            squelch=False,
#        ),
        DigitalMode(
            "page",
            "Page",
            underlying=["empty"],
            bandpass=Bandpass(-6000, 6000),
            requirements=["page"],
            service=True,
            squelch=False,
        ),
        DigitalMode("cwdecoder", "CW Decoder", underlying=["usb", "lsb"]),
# Replaced by Jakob's RTTY decoder
#        DigitalMode("mfrtty170", "RTTY-170", underlying=["usb"]),
#        DigitalMode("mfrtty450", "RTTY-450", underlying=["usb"]),
        DigitalMode(
            "sstv",
            "SSTV",
            underlying=["usb", "lsb", "nfm"],
            service=True,
            squelch=True,
        ),
        DigitalMode(
            "fax",
            "Fax",
            underlying=["usb"],
            service=True,
            squelch=True,
        ),
        DigitalMode(
            "selcall",
            "SelCall",
            underlying=["nfm"],
            requirements=["selcall"],
            squelch=True
        ),

       
        DigitalMode(
            "hfdl",
            "HFDL",
            underlying=["empty"],
            bandpass=Bandpass(0, 3000),
            requirements=["hfdl"],
            service=True,
            squelch=False
        ),

        DigitalMode(
            "acars",
            "ACARS",
            underlying=["am"],
            bandpass=Bandpass(-6250, 6250),
            requirements=["acars"],
            service=True,
            squelch=False
        ),

    ]

    @staticmethod
    def getModes():
        return Modes.mappings

    @staticmethod
    def getAvailableModes():
        return [m for m in Modes.getModes() if m.is_available()]

    @staticmethod
    def getAvailableServices():
        return [m for m in Modes.getAvailableModes() if m.is_service()]

    @staticmethod
    def findByModulation(modulation):
        modes = [m for m in Modes.getAvailableModes() if m.modulation == modulation]
        if modes:
            return modes[0]
