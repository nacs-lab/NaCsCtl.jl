#

import NaCsCtl.IR

builder = IR.Builder(IR.Value.Float64, [IR.Value.Float64])
IR.createRet(builder, 0);
@test sprint(show, get(builder)) == """
Float64 (Float64 %0) {
L0:
  ret Float64 %0
}
"""
