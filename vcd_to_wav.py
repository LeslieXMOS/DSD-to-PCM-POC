import io
from vcd.reader import TokenKind, tokenize
import numpy as np
import scipy.io.wavfile as wavfile

vcd_file = open("xscope.vcd", "rb")
vcd_file.readline()
vcd_file.readline()
vcd_file.readline()
tokens = tokenize(vcd_file)

data = []

for token in tokens:
    if token.kind == TokenKind.CHANGE_VECTOR:
        if token.data.id_code == '0':
            v = token.data.value
            if v > 2**33:
                v -= 2**64
            data.append(v)

data = np.asarray(data, dtype=np.int32)
print(data.shape)
wavfile.write("xscope.wav", 176400, data)