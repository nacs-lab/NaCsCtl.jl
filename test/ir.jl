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
end
