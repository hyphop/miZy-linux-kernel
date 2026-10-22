import os,termios,select,time,binascii,pathlib,sys
fd=os.open('/dev/cu.usbserial-1110',os.O_RDWR|os.O_NOCTTY|os.O_NONBLOCK)
def baud(n):
 a=termios.tcgetattr(fd);a[0]=a[1]=a[3]=0;a[2]=termios.CS8|termios.CREAD|termios.CLOCAL;a[4]=a[5]=getattr(termios,'B'+str(n));a[6][termios.VMIN]=a[6][termios.VTIME]=0;termios.tcsetattr(fd,termios.TCSANOW,a)
def write(b):
 while b:
  if select.select([],[fd],[],5)[1]:
   try:n=os.write(fd,b);b=b[n:]
   except BlockingIOError:pass
  else:raise TimeoutError('serial write')
def read(t):
 data=b'';end=time.monotonic()+t
 while time.monotonic()<end:
  if select.select([fd],[],[],0.1)[0]:data+=os.read(fd,65536)
 return data
def expect(vals,t=10):
 end=time.monotonic()+t;seen=b''
 while time.monotonic()<end:
  if select.select([fd],[],[],0.2)[0]:
   c=os.read(fd,1)
   if c and c[0] in vals:return c[0]
   seen+=c
 raise TimeoutError('Expected '+repr(vals)+' got '+repr(seen[-300:]))
def pkt(num,data):
 size=len(data);return bytes([1 if size==128 else 2,num,255-num])+data+binascii.crc_hqx(data,0).to_bytes(2,'big')
def acknowledged(packet):
 for i in range(10):
  write(packet);c=expect([6,21,24],15)
  if c==6:return
  if c==24:raise RuntimeError('Receiver cancelled')
 raise RuntimeError('Too many retries')
try:
 baud(115200);time.sleep(.3);termios.tcflush(fd,termios.TCIFLUSH);write(b'\r');print(read(1).decode(errors='replace'),flush=True)
 address=int(sys.argv[2],0) if len(sys.argv)>2 else 0x48000000
 write(f'loady {address:#x}\r'.encode());expect([67],15)
 data=pathlib.Path(sys.argv[1]).read_bytes()
 head=(b'mizy-test.itb\0'+str(len(data)).encode()+b'\0').ljust(128,b'\0')
 acknowledged(pkt(0,head));expect([67],15)
 total=len(data);start=time.monotonic();reported=0
 for i,off in enumerate(range(0,total,1024)):
  acknowledged(pkt((i+1)%256,data[off:off+1024].ljust(1024,b'\x1a')))
  done=min(off+1024,total)
  if done-reported>=524288 or done==total:
   print(f'Transferred {done}/{total} bytes ({done*100//total}%), {time.monotonic()-start:.0f}s',flush=True);reported=done
 write(b'\x04');c=expect([6,21,24],15)
 if c==21:write(b'\x04');expect([6],15)
 elif c!=6:raise RuntimeError('EOT cancelled')
 expect([67],15);acknowledged(pkt(0,b'\0'*128))
 print('UPLOAD_COMPLETE\n'+read(2).decode(errors='replace'),flush=True)
 if len(sys.argv)<4 or sys.argv[3]!='raw':
  write(f'iminfo {address:#x}\r'.encode());print(read(3).decode(errors='replace'),flush=True)
finally:os.close(fd)
