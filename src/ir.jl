# Copyright (c) 2014-2016, Yichao Yu <yyc1992@gmail.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 3.0 of the License, or (at your option) any later version.
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
# You should have received a copy of the GNU Lesser General Public
# License along with this library.

module IR

const empty_sym = Symbol("")

baremodule Value
import ...@named_consts
@named_consts 8 Type Bool=1 Int32 Float64
end
function typeName(v::Value.Type)
    tname = constname(v)
    if tname === empty_sym
        return :Bottom
    end
    return tname
end

baremodule OP
import ...@named_consts
@named_consts 8 Type ret=1 br add sub mul fdiv cmp phi call
end
function opName(v::OP.Type)
    name = constname(v)
    if name === empty_sym
        return :unknown
    end
    return name
end

baremodule Cmp
import ...@named_consts
@named_consts 8 Type eq gt ge lt le ne
end
function cmpName(v::Cmp.Type)
    name = constname(v)
    if name === empty_sym
        return :unknown
    end
    return name
end

baremodule Builtin
import ...@named_consts
@named_consts(8, Id,
              # f(f)
              acos, acosh, asin, asinh, atan, atanh, cbrt, ceil, cos, cosh,
              erf, erfc, exp, exp10, exp2, expm1, abs, floor, gamma,
              j0, j1, lgamma, log, log10, log1p, log2, pow10,
              rint, round, sin, sinh, sqrt, tan, tanh, y0, y1,
              # f(f, f)
              atan2, copysign, fdim, max, min, mod, hypot, pow, remainder,
              # f(f, f, f)
              fma,
              # f(f, i)
              ldexp,
              # f(i, f)
              jn, yn)
@named_consts(8, Type, Invalid,
              F64_F64, F64_F64F64, F64_F64F64F64, F64_F64I32, F64_I32F64)
end
function builtinName(v::Builtin.Id)
    name = constname(v)
    if name === empty_sym
        return :unknown
    end
    return name
end

baremodule Consts
const False = Int32(-1)
const True = Int32(-2)
const _Offset = Int32(-3)
end

bitstype 64 GenVal
Base.Bool(v::GenVal) = (reinterpret(UInt64, v) % UInt8) != 0
Base.Int32(v::GenVal) = reinterpret(UInt64, v) % Int32
Base.Float64(v::GenVal) = reinterpret(Float64, v)
GenVal(v::Bool) = reinterpret(GenVal, UInt64(v))
GenVal(v::Int32) = reinterpret(GenVal, v % UInt64)
GenVal(v::Float64) = reinterpret(GenVal, v)
Base.cconvert{T<:Union{Bool,Int32,Float64}}(::Type{T}, v::GenVal) = T(v)

immutable TagVal
    typ::Value.Type
    val::GenVal
    TagVal(typ=Value.Bool, val=reinterpret(GenVal, UInt64(0))) = new(typ, val)
    TagVal(b::Bool) = new(Value.Bool, GenVal(b))
    TagVal(i::Integer) = new(Value.Int32, GenVal(Int32(i)))
    TagVal(f::AbstractFloat) = new(Value.Float64, GenVal(Float64(f)))
end
Base.Bool(v::TagVal) = Bool(v.val)
function Base.Int32(v::TagVal)::Int32
    if v.typ == Value.Bool
        return Bool(v.val)
    elseif v.typ == Value.Int32
        return Int32(v.val)
    elseif v.typ == Value.Float64
        return trunc(Int32, Float64(v.val))
    end
end
function Base.Float64(v::TagVal)::Float64
    if v.typ == Value.Bool
        return Bool(v.val)
    elseif v.typ == Value.Int32
        return Int32(v.val)
    elseif v.typ == Value.Float64
        return Float64(v.val)
    end
end
function Base.show(io::IO, v::TagVal)
    print(io, typeName(v.typ), " ")
    if v.typ == Value.Bool
        print(io, Bool(v.val))
    elseif v.typ == Value.Int32
        print(io, Int32(v.val))
    elseif v.typ == Value.Float64
        print(io, Float64(v.val))
    else
        print(io, "undef")
    end
end

# LLVM does not optimize this. =(
function getBuiltinType(id::Builtin.Id)
    if (id == Builtin.acos || id == Builtin.acosh ||
        id == Builtin.asin || id == Builtin.asinh ||
        id == Builtin.atan || id == Builtin.atanh ||
        id == Builtin.cbrt || id == Builtin.ceil ||
        id == Builtin.cos || id == Builtin.cosh ||
        id == Builtin.erf || id == Builtin.erfc ||
        id == Builtin.exp || id == Builtin.exp10 || id == Builtin.exp2 ||
        id == Builtin.expm1 || id == Builtin.abs || id == Builtin.floor ||
        id == Builtin.gamma || id == Builtin.j0 || id == Builtin.j1 ||
        id == Builtin.lgamma || id == Builtin.log || id == Builtin.log10 ||
        id == Builtin.log1p || id == Builtin.log2 || id == Builtin.pow10 ||
        id == Builtin.rint || id == Builtin.round ||
        id == Builtin.sin || id == Builtin.sinh ||
        id == Builtin.sqrt || id == Builtin.tan || id == Builtin.tanh ||
        id == Builtin.y0 || id == Builtin.y1)
        return Builtin.F64_F64
    end
    if (id == Builtin.atan2 || id == Builtin.copysign || id == Builtin.fdim ||
        id == Builtin.max || id == Builtin.min || id == Builtin.mod ||
        id == Builtin.hypot || id == Builtin.pow || id == Builtin.remainder)
        return Builtin.F64_F64F64
    end
    if id == Builtin.fma
        return Builtin.F64_F64F64F64
    end
    if id == Builtin.ldexp
        return Builtin.F64_F64I32
    end
    if id == Builtin.jn || id == Builtin.yn
        return Builtin.F64_I32F64
    end
    return Builtin.Invalid
end

function checkBuiltinType(id::Builtin.Id, args)
    narg = length(args)
    typ = getBuiltinType(id)
    @inbounds if typ == Builtin.F64_F64
        return narg == 1 && args[0] == Value.Float64;
    elseif typ == Builtin.F64_F64F64
        return narg == 2 && args[0] == Value.Float64 && args[1] == Value.Float64
    elseif typ == Builtin.F64_F64F64F64
        return (narg == 3 && args[0] == Value.Float64 &&
                args[1] == Value.Float64 && args[2] == Value.Float64)
    elseif typ == Builtin.F64_F64I32
        return narg == 2 && args[0] == Value.Float64 && args[1] == Value.Int32
    elseif typ == Builtin.F64_I32F64
        return narg == 2 && args[0] == Value.Int32 && args[1] == Value.Float64
    else
        return false
    end
end

const builtin_ptrs = Vector{Ptr{Void}}(Int(typemax(Builtin.Id)) + 1)

@inline function fill_builtin(id, libm_hdl, self_hdl, sym)
    ptr = Libdl.dlsym_e(libm_hdl, sym)
    if ptr == C_NULL
        ptr = Libdl.dlsym_e(self_hdl, sym)
    end
    if ptr == C_NULL
        if sym === :exp10
            ptr = cfunction(exp10, Float64, (Float64,))
        elseif sym === :abs
            ptr = cfunction(abs, Float64, (Float64,))
        else
            error("Cannot find function $sym")
        end
    end
    builtin_ptrs[Int(id) + 1] = ptr
    return
end

function __init__()
    libm_hdl = Libdl.dlopen(Base.libm_name)
    self_hdl = ccall(:jl_load_dynamic_library,
                     Ptr{Void}, (Ptr{Void}, UInt32),
                     C_NULL, Libdl.RTLD_LAZY | Libdl.RTLD_DEEPBIND)
    # f(f)
    fill_builtin(Builtin.acos, libm_hdl, self_hdl, :acos)
    fill_builtin(Builtin.acosh, libm_hdl, self_hdl, :acosh)
    fill_builtin(Builtin.asin, libm_hdl, self_hdl, :asin)
    fill_builtin(Builtin.asinh, libm_hdl, self_hdl, :asinh)
    fill_builtin(Builtin.atan, libm_hdl, self_hdl, :atan)
    fill_builtin(Builtin.atanh, libm_hdl, self_hdl, :atanh)
    fill_builtin(Builtin.cbrt, libm_hdl, self_hdl, :cbrt)
    fill_builtin(Builtin.ceil, libm_hdl, self_hdl, :ceil)
    fill_builtin(Builtin.cos, libm_hdl, self_hdl, :cos)
    fill_builtin(Builtin.cosh, libm_hdl, self_hdl, :cosh)
    fill_builtin(Builtin.erf, libm_hdl, self_hdl, :erf)
    fill_builtin(Builtin.erfc, libm_hdl, self_hdl, :erfc)
    fill_builtin(Builtin.exp, libm_hdl, self_hdl, :exp)
    fill_builtin(Builtin.exp10, libm_hdl, self_hdl, :exp10)
    fill_builtin(Builtin.exp2, libm_hdl, self_hdl, :exp2)
    fill_builtin(Builtin.expm1, libm_hdl, self_hdl, :expm1)
    fill_builtin(Builtin.abs, libm_hdl, self_hdl, :abs)
    fill_builtin(Builtin.floor, libm_hdl, self_hdl, :floor)
    fill_builtin(Builtin.gamma, libm_hdl, self_hdl, :tgamma)
    fill_builtin(Builtin.j0, libm_hdl, self_hdl, :j0)
    fill_builtin(Builtin.j1, libm_hdl, self_hdl, :j1)
    fill_builtin(Builtin.lgamma, libm_hdl, self_hdl, :lgamma)
    fill_builtin(Builtin.log, libm_hdl, self_hdl, :log)
    fill_builtin(Builtin.log10, libm_hdl, self_hdl, :log10)
    fill_builtin(Builtin.log1p, libm_hdl, self_hdl, :log1p)
    fill_builtin(Builtin.log2, libm_hdl, self_hdl, :log2)
    fill_builtin(Builtin.pow10, libm_hdl, self_hdl, :exp10)
    fill_builtin(Builtin.rint, libm_hdl, self_hdl, :rint)
    fill_builtin(Builtin.round, libm_hdl, self_hdl, :round)
    fill_builtin(Builtin.sin, libm_hdl, self_hdl, :sin)
    fill_builtin(Builtin.sinh, libm_hdl, self_hdl, :sinh)
    fill_builtin(Builtin.sqrt, libm_hdl, self_hdl, :sqrt)
    fill_builtin(Builtin.tan, libm_hdl, self_hdl, :tan)
    fill_builtin(Builtin.tanh, libm_hdl, self_hdl, :tanh)
    fill_builtin(Builtin.y0, libm_hdl, self_hdl, :y0)
    fill_builtin(Builtin.y1, libm_hdl, self_hdl, :y1)

    # f(f, f)
    fill_builtin(Builtin.atan2, libm_hdl, self_hdl, :atan2)
    fill_builtin(Builtin.copysign, libm_hdl, self_hdl, :copysign)
    fill_builtin(Builtin.fdim, libm_hdl, self_hdl, :fdim)
    fill_builtin(Builtin.max, libm_hdl, self_hdl, :fmax)
    fill_builtin(Builtin.min, libm_hdl, self_hdl, :fmin)
    fill_builtin(Builtin.mod, libm_hdl, self_hdl, :fmod)
    fill_builtin(Builtin.hypot, libm_hdl, self_hdl, :hypot)
    fill_builtin(Builtin.pow, libm_hdl, self_hdl, :pow)
    fill_builtin(Builtin.remainder, libm_hdl, self_hdl, :remainder)

    # f(f, f, f)
    fill_builtin(Builtin.fma, libm_hdl, self_hdl, :fma)

    # f(f, i)
    fill_builtin(Builtin.ldexp, libm_hdl, self_hdl, :ldexp)

    # f(i, f)
    fill_builtin(Builtin.jn, libm_hdl, self_hdl, :jn)
    fill_builtin(Builtin.yn, libm_hdl, self_hdl, :yn)
end

function evalBuiltin(id::Builtin.Id, args)
    fptr = builtin_ptrs[Int(id) + 1]
    typ = getBuiltinType(id)
    if typ == Builtin.F64_F64
        return ccall(fptr, Float64, (Float64,), args[1])
    elseif typ == Builtin.F64_F64F64
        return ccall(fptr, Float64, (Float64, Float64), args[1], args[2])
    elseif typ == Builtin.F64_F64F64F64
        return ccall(fptr, Float64, (Float64, Float64, Float64),
                     args[1], args[2], args[3])
    elseif typ == Builtin.F64_F64I32
        return ccall(fptr, Float64, (Float64, Int32), args[1], args[2])
    elseif typ == Builtin.F64_I32F64
        return ccall(fptr, Float64, (Int32, Float64), args[1], args[2])
    else
        return 0.0
    end
end

end
