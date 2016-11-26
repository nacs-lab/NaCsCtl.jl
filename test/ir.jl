#

import NaCsCtl.IR

@testset "Return arg" begin
    builder = IR.Builder(IR.Value.Float64, [IR.Value.Float64])
    IR.createRet(builder, 0)
    @test string(get(builder)) == """
Float64 (Float64 %0) {
L0:
  ret Float64 %0
}
"""
end

@testset "Return const" begin
    builder = IR.Builder(IR.Value.Bool, [])
    IR.createRet(builder, IR.Consts.False)
    @test string(get(builder)) == """
Bool () {
L0:
  ret Bool false
}
"""

    builder = IR.Builder(IR.Value.Float64, [])
    IR.createRet(builder, IR.getConstFloat(builder, 1.1))
    @test string(get(builder)) == """
Float64 () {
L0:
  ret Float64 1.1
}
"""

    builder = IR.Builder(IR.Value.Int32, [])
    IR.createRet(builder, IR.getConstInt(builder, 42))
    @test string(get(builder)) == """
Int32 () {
L0:
  ret Int32 42
}
"""
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
    @test string(get(builder)) == """
Float64 (Bool %0, Float64 %1) {
L0:
  br Bool %0, L1, L2
L1:
  ret Float64 %1
L2:
  ret Float64 3.5
}
"""
end

@testset "BinOps" begin
    builder = IR.Builder(IR.Value.Float64, [IR.Value.Float64, IR.Value.Float64])
    val1 = IR.createAdd(builder, IR.getConstFloat(builder, 3.4), 0)
    val2 = IR.createMul(builder, val1, 1)
    val3 = IR.createSub(builder, val1, val2)
    IR.createRet(builder, val3)
    @test string(get(builder)) == """
Float64 (Float64 %0, Float64 %1) {
L0:
  Float64 %2 = add Float64 3.4, Float64 %0
  Float64 %3 = mul Float64 %2, Float64 %1
  Float64 %4 = sub Float64 %2, Float64 %3
  ret Float64 %4
}
"""

    builder = IR.Builder(IR.Value.Float64, [IR.Value.Int32, IR.Value.Int32])
    val1 = IR.createFDiv(builder, 0, 1)
    IR.createRet(builder, val1)
    @test string(get(builder)) == """
Float64 (Int32 %0, Int32 %1) {
L0:
  Float64 %2 = fdiv Int32 %0, Int32 %1
  ret Float64 %2
}
"""
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
    @test string(get(builder)) == """
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
    @test string(get(builder)) == """
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
end
