#!/usr/bin/env python3
# Design + self-test the hardened cipher (Feistel, invertible by construction).
# Nonlinearity from the recovered 8-bit S-box; tuned until avalanche ~50%.
import json, random, itertools, os
HERE=os.path.dirname(os.path.abspath(__file__))
T=json.load(open(os.path.join(HERE,"..","recovery","cipher_tables.json")))
S = T["enc"][0][:]                 # recovered 8-bit bijection (lane 0) as S-box
Sinv=[0]*256
for i,v in enumerate(S): Sinv[v]=i
MASK16=0xFFFF
def rotl16(x,r): x&=MASK16; return ((x<<r)|(x>>(16-r)))&MASK16
RC=[0x9E37,0x79B9,0x7F4A,0x7C15,0x2B54,0xF1A3,0xC6EF,0x3779,
    0xB5C0,0xA1E2,0x51D3,0x0F2B,0x63A9,0xD48C,0x37E1,0x8B4D]
def key_schedule(K, N):
    rk=[]
    for r in range(N):
        w=((K<<(r%29))|(K>>(32-(r%29)) if r%29 else 0))&0xFFFFFFFF
        rk.append(((w>>((r*3)%17)) ^ (RC[r%len(RC)]<<((r%2)*0)) ^ RC[r%len(RC)]) & MASK16)
    return rk
def F(R, rk, ra, rb):
    t = (R ^ rk) & MASK16
    t = (S[t & 0xFF] | (S[(t>>8)&0xFF] << 8)) & MASK16      # nonlinear
    t = (t ^ rotl16(t,ra) ^ rotl16(t,rb)) & MASK16          # linear diffusion
    return t
def enc(x, K, N, ra, rb):
    L=(x>>16)&MASK16; R=x&MASK16; rk=key_schedule(K,N)
    for r in range(N):
        L,R = R, (L ^ F(R,rk[r],ra,rb))&MASK16
    return ((L<<16)|R)&0xFFFFFFFF
def dec(x, K, N, ra, rb):
    L=(x>>16)&MASK16; R=x&MASK16; rk=key_schedule(K,N)
    for r in reversed(range(N)):
        R,L = L, (R ^ F(L,rk[r],ra,rb))&MASK16
    return ((L<<16)|R)&0xFFFFFFFF

def avalanche(K,N,ra,rb,trials=2000):
    random.seed(1); tot=0; cnt=0; worst_min=32; worst_max=0
    perbit=[0]*32
    for _ in range(trials):
        x=random.getrandbits(32); y=enc(x,K,N,ra,rb)
        b=random.randrange(32); y2=enc(x^(1<<b),K,N,ra,rb)
        d=bin(y^y2).count("1"); tot+=d; cnt+=1
    return tot/cnt

def roundtrip(K,N,ra,rb,trials=3000):
    random.seed(2)
    for _ in range(trials):
        x=random.getrandbits(32)
        if dec(enc(x,K,N,ra,rb),K,N,ra,rb)!=x: return False
    return True

K=0xC0DECAFE
best=None
for N in (8,10,12,16):
    for ra,rb in [(3,7),(5,11),(1,7),(3,11),(2,13)]:
        if not roundtrip(K,N,ra,rb): continue
        av=avalanche(K,N,ra,rb)
        score=abs(av-16.0)
        if best is None or score<best[0]:
            best=(score,N,ra,rb,av)
print("best config: N=%d ra=%d rb=%d avalanche=%.2f bits (ideal 16)"%(best[1],best[2],best[3],best[4]))
N,ra,rb=best[1],best[2],best[3]
# final checks
print("round-trip over 3000 random:", roundtrip(K,N,ra,rb))
# bijection check on a sample: ensure distinct
random.seed(9); xs=[random.getrandbits(32) for _ in range(5000)]
ys=set(enc(x,K,N,ra,rb) for x in xs)
print("injective on 5000 samples:", len(ys)==len(xs))
# emit chosen params
json.dump({"N":N,"ra":ra,"rb":rb,"K":K,"S":S,"Sinv":Sinv,"RC":RC,
           "rk":key_schedule(K,N)}, open(os.path.join(HERE,"hardened_params.json"),"w"))
print("wrote hardened_params.json ; rk=", [hex(k) for k in key_schedule(K,N)])
