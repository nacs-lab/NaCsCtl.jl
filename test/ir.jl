#

import NaCsCtl.IR

@testset "Return arg" begin
    builder = IR.Builder(IR.Value.Float64, [IR.Value.Float64])
    IR.createRet(builder, 0)
    @test sprint(show, get(builder)) == """
Float64 (Float64 %0) {
L0:
  ret Float64 %0
}
"""
end

@testset "Return const" begin
    builder = IR.Builder(IR.Value.Bool, [])
    IR.createRet(builder, IR.Consts.False)
    @test sprint(show, get(builder)) == """
Bool () {
L0:
  ret Bool false
}
"""
    builder = IR.Builder(IR.Value.Float64, [])
    IR.createRet(builder, IR.getConstFloat(builder, 1.1))
    @test sprint(show, get(builder)) == """
Float64 () {
L0:
  ret Float64 1.1
}
"""
    builder = IR.Builder(IR.Value.Int32, [])
    IR.createRet(builder, IR.getConstInt(builder, 42))
    @test sprint(show, get(builder)) == """
Int32 () {
L0:
  ret Int32 42
}
"""
end
