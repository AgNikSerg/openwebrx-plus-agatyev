from csdr.module import PopenModule
from pycsdr.types import Format
from pycsdr.modules import Writer
from subprocess import Popen, PIPE
from threading import Thread

import re
import pickle


class M17Module(PopenModule):
 

    def __init__(self):
        super().__init__()
        self.metawriter = None

    def getInputFormat(self) -> Format:
        return Format.SHORT

    def getOutputFormat(self) -> Format:
        return Format.SHORT

    def getCommand(self):
        return ["dsd-fme","-i", "-", "-o", "-", "-g 0", "-u 1"]

    def setMetaWriter(self, writer: Writer) -> None:
        self.metawriter = writer