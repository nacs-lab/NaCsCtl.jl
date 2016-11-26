#

import NaCsCtl.IR

const take_i32 = if VERSION >= v"0.6.0-dev.1256"
    x->reinterpret(Int32, take!(x))
else
    x->reinterpret(Int32, takebuf_array(x))
end

@testset "Return arg" begin
    builder = IR.Builder(IR.Value.Float64, [IR.Value.Float64])
    IR.createRet(builder, 0)
    f = get(builder)
    @test string(f) == """
Float64 (Float64 %0) {
L0:
  ret Float64 %0
}
"""
    ctx = IR.EvalContext(f)
    ctx[:] = 1.2
    @test ctx() == IR.TagVal(1.2)
    ctx[:] = 4.2
    @test ctx() == IR.TagVal(4.2)
end

@testset "Return const" begin
    builder = IR.Builder(IR.Value.Bool, [])
    IR.createRet(builder, IR.Consts.False)
    f = get(builder)
    @test string(f) == """
Bool () {
L0:
  ret Bool false
}
"""
    ctx = IR.EvalContext(f)
    @test ctx() == IR.TagVal(false)

    builder = IR.Builder(IR.Value.Float64, [])
    IR.createRet(builder, IR.getConstFloat(builder, 1.1))
    f = get(builder)
    @test string(f) == """
Float64 () {
L0:
  ret Float64 1.1
}
"""
    ctx = IR.EvalContext(f)
    @test ctx() == IR.TagVal(1.1)

    builder = IR.Builder(IR.Value.Int32, [])
    IR.createRet(builder, IR.getConstInt(builder, 42))
    f = get(builder)
    @test string(f) == """
Int32 () {
L0:
  ret Int32 42
}
"""
    ctx = IR.EvalContext(f)
    @test ctx() == IR.TagVal(Int32(42))
end

@testset "Branch" begin
    builder = IR.Builder(IR.Value.Float64, [IR.Value.Bool, IR.Value.Float64])
    pass_bb = IR.newBB(builder)
    fail_bb = IR.newBB(builder)
    IR.createBr(builder, 0, pass_bb, fail_bb)
    IR.setCurBB(builder, pass_bb)
    IR.createRet(builder, 1)
    IR.setCurBB(builder, fail_bb)
    IR.createRet(builder, IR.getConstFloat(builder, 3.5f0))
    f = get(builder)
    @test string(f) == """
Float64 (Bool %0, Float64 %1) {
L0:
  br Bool %0, L1, L2
L1:
  ret Float64 %1
L2:
  ret Float64 3.5
}
"""
    ctx = IR.EvalContext(f)
    ctx[1] = true
    ctx[2] = 1.3
    @test ctx() == IR.TagVal(1.3)
    ctx[1] = false
    ctx[2] = 1.3
    @test ctx() == IR.TagVal(3.5)
end

@testset "BinOps" begin
    builder = IR.Builder(IR.Value.Float64, [IR.Value.Float64, IR.Value.Float64])
    val1 = IR.createAdd(builder, IR.getConstFloat(builder, 3.4), 0)
    val2 = IR.createMul(builder, val1, 1)
    val3 = IR.createSub(builder, val1, val2)
    IR.createRet(builder, val3)
    f = get(builder)
    @test string(f) == """
Float64 (Float64 %0, Float64 %1) {
L0:
  Float64 %2 = add Float64 3.4, Float64 %0
  Float64 %3 = mul Float64 %2, Float64 %1
  Float64 %4 = sub Float64 %2, Float64 %3
  ret Float64 %4
}
"""
    ctx = IR.EvalContext(f)
    ctx[1] = 2.3
    ctx[2] = 1.3
    @test ctx() == IR.TagVal(-1.71)

    builder = IR.Builder(IR.Value.Float64, [IR.Value.Int32, IR.Value.Int32])
    val1 = IR.createFDiv(builder, 0, 1)
    IR.createRet(builder, val1)
    f = get(builder)
    @test string(f) == """
Float64 (Int32 %0, Int32 %1) {
L0:
  Float64 %2 = fdiv Int32 %0, Int32 %1
  ret Float64 %2
}
"""
    ctx = IR.EvalContext(f)
    ctx[1] = 3
    ctx[2] = 2
    @test ctx() == IR.TagVal(1.5)
end

@testset "Compare" begin
    builder = IR.Builder(IR.Value.Float64, [IR.Value.Int32, IR.Value.Float64])
    pass_bb = IR.newBB(builder)
    fail_bb = IR.newBB(builder)
    IR.createBr(builder, IR.createCmp(builder, IR.Cmp.ge, 0, 1),
                pass_bb, fail_bb)
    IR.setCurBB(builder, pass_bb)
    IR.createRet(builder, 1)
    IR.setCurBB(builder, fail_bb)
    IR.createRet(builder, 0)
    f = get(builder)
    @test string(f) == """
Float64 (Int32 %0, Float64 %1) {
L0:
  Bool %2 = cmp ge Int32 %0, Float64 %1
  br Bool %2, L1, L2
L1:
  ret Float64 %1
L2:
  ret Int32 %0
}
"""
    ctx = IR.EvalContext(f)
    ctx[1] = 20
    ctx[2] = 1.3
    @test ctx() == IR.TagVal(1.3)
    ctx[1] = -10
    ctx[2] = 1.3
    @test ctx() == IR.TagVal(-10.0)
end

@testset "Loop" begin
    builder = IR.Builder(IR.Value.Int32, [IR.Value.Int32, IR.Value.Int32])
    loop_bb = IR.newBB(builder)
    ret_bb = IR.newBB(builder)
    IR.createBr(builder, loop_bb)
    IR.setCurBB(builder, loop_bb)
    i = IR.createPhi(builder, IR.Value.Int32, 2)
    s = IR.createPhi(builder, IR.Value.Int32, 2)
    IR.addPhiInput(builder, i[2], 0, 0)
    IR.addPhiInput(builder, s[2], 0, IR.getConstInt(builder, 0))
    i2 = IR.createAdd(builder, i[1], IR.getConstInt(builder, 1))
    s2 = IR.createAdd(builder, s[1], i[1])
    cond = IR.createCmp(builder, IR.Cmp.gt, i2, 1)
    IR.createBr(builder, cond, ret_bb, loop_bb)
    IR.addPhiInput(builder, i[2], loop_bb, i2)
    IR.addPhiInput(builder, s[2], loop_bb, s2)
    IR.setCurBB(builder, ret_bb)
    IR.createRet(builder, s2)
    f = get(builder)
    @test string(f) == """
Int32 (Int32 %0, Int32 %1) {
L0:
  br L1
L1:
  Int32 %2 = phi [ L0: Int32 %0 ], [ L1: Int32 %4 ]
  Int32 %3 = phi [ L0: Int32 0 ], [ L1: Int32 %5 ]
  Int32 %4 = add Int32 %2, Int32 1
  Int32 %5 = add Int32 %3, Int32 %2
  Bool %6 = cmp gt Int32 %4, Int32 %1
  br Bool %6, L2, L1
L2:
  ret Int32 %5
}
"""
    ctx = IR.EvalContext(f)
    ctx[1] = 1
    ctx[2] = 3
    @test ctx() == IR.TagVal(Int32(6))
    ctx[1] = 2
    ctx[2] = 1000
    @test ctx() == IR.TagVal(Int32(500499))
end

@testset "Builtin" begin
    builder = IR.Builder(IR.Value.Float64, [IR.Value.Int32])
    IR.createRet(builder,
                 IR.createAdd(builder,
                              IR.createCall(builder, IR.Builtin.sin, (0,)),
                              IR.createCall(builder, IR.Builtin.sin, (
                                  IR.createMul(builder, 0,
                                               IR.getConstInt(builder, 2))
                              ))))
    f = get(builder)
    @test string(f) == """
Float64 (Int32 %0) {
L0:
  Float64 %1 = call sin(Int32 %0)
  Int32 %2 = mul Int32 %0, Int32 2
  Float64 %3 = call sin(Int32 %2)
  Float64 %4 = add Float64 %1, Float64 %3
  ret Float64 %4
}
"""
    ctx = IR.EvalContext(f)
    ctx[1] = 1
    @test ctx() == IR.TagVal(sin(1) + sin(2))
    ctx[1] = 2
    @test ctx() == IR.TagVal(sin(2) + sin(4))

    io = IOBuffer()
    write(io, f)
    seek(io, 0)
    f = read(io, IR.Func)
    ctx = IR.EvalContext(f)
    ctx[1] = 1
    @test ctx() == IR.TagVal(sin(1) + sin(2))
    ctx[1] = 2
    @test ctx() == IR.TagVal(sin(2) + sin(4))
end

@testset "Serialize" begin
    data = Int32[3, 2, 6, 50529027, 771, 1, 3, 0, 1073741824, 1, 14, 5,
                 5, 0, -3, 3, 4, 5, -3, 3, 2, 3, 1, 1, 2]
    func = read(IOBuffer(reinterpret(UInt8, data)), IR.Func)
    @test string(func) == """
Float64 (Float64 %0, Float64 %1) {
L0:
  Float64 %5 = mul Float64 %0, Float64 2.0
  Float64 %4 = add Float64 %5, Float64 2.0
  Float64 %2 = add Float64 %3, Float64 %1
  ret Float64 %2
}
"""
    io = IOBuffer()
    write(io, func)
    @test take_i32(io) == data

    data = Int32[3, 2, 7, 50529027, 197379, 2, 3, 0, 1072693248, 3, 0,
                 1073741824, 1, 22, 4, 5, -3, 0, 5, 4, -3, 5, 5, 6, -4, 0, 3, 3,
                 4, 6, 6, 2, 3, -3, 1, 2]
    func = read(IOBuffer(reinterpret(UInt8, data)), IR.Func)
    @test string(func) == """
Float64 (Float64 %0, Float64 %1) {
L0:
  Float64 %5 = sub Float64 1.0, Float64 %0
  Float64 %4 = mul Float64 1.0, Float64 %5
  Float64 %6 = mul Float64 2.0, Float64 %0
  Float64 %3 = add Float64 %4, Float64 %6
  Float64 %2 = fdiv Float64 %3, Float64 1.0
  ret Float64 %2
}
"""
    io = IOBuffer()
    write(io, func)
    @test take_i32(io) == data
end

@testset "Names" begin
    @test IR.typeName(IR.Value.Float64) === :Float64
    @test IR.typeName(IR.Value.Type(-1)) === :Bottom

    @test IR.opName(IR.OP.ret) === :ret
    @test IR.opName(IR.OP.Type(-1)) === :unknown

    @test IR.cmpName(IR.Cmp.eq) === :eq
    @test IR.cmpName(IR.Cmp.Type(-1)) === :unknown

    @test IR.builtinName(IR.Builtin.sin) === :sin
    @test IR.builtinName(IR.Builtin.Id(-1)) === :unknown
end
