/-! Probe: ctor with mixed UInt64/UInt32/UInt16/UInt8 scalar tail fields. -/

structure WideRecord where
  a : UInt64
  b : UInt64
  c : UInt64
  d : UInt64
  e : UInt64
  f : UInt64
  g : UInt64
  h : UInt64
  i : UInt32
  j : UInt32
  k : UInt16
  l : UInt16
  m : UInt8
  n : UInt8
  o : UInt8
  p : UInt8

@[noinline]
def projWide (r : WideRecord) : UInt64 :=
  r.a + r.b + r.c + r.d + r.e + r.f + r.g + r.h
    + r.i.toUInt64 + r.j.toUInt64
    + r.k.toUInt64 + r.l.toUInt64
    + r.m.toUInt64 + r.n.toUInt64 + r.o.toUInt64 + r.p.toUInt64

@[noinline]
def mkWide : WideRecord :=
  { a := 0x0100000000000000, b := 0x0200000000000000, c := 0x0400000000000000
  , d := 0x0800000000000000, e := 0x1000000000000000, f := 0x2000000000000000
  , g := 0x4000000000000000, h := 0x8000000000000000
  , i := 0x10000000, j := 0x20000000
  , k := 0x1000, l := 0x2000
  , m := 0x10, n := 0x20, o := 0x40, p := 0x80 }

@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let r := mkWide
  let s := projWide r
  let expected : UInt64 :=
    0x0100000000000000 + 0x0200000000000000 + 0x0400000000000000 + 0x0800000000000000
      + 0x1000000000000000 + 0x2000000000000000 + 0x4000000000000000 + 0x8000000000000000
      + 0x10000000 + 0x20000000
      + 0x1000 + 0x2000
      + 0x10 + 0x20 + 0x40 + 0x80
  if s == expected then 0 else 99
