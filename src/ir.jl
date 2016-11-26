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
import ..constname

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
    fill_builtin(Builtin.abs, libm_hdl, self_hdl, :fabs)
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

immutable Func
    ret::Value.Type
    nargs::Int32
    vals::Vector{Value.Type}
    code::Vector{Vector{Int32}}
    consts::Vector{TagVal}
    function Func(ret::Value.Type, args)
        nargs = Int32(length(args))
        func = Func(ret, nargs)
        copy!(func.vals, args)
        return func
    end
    function Func(ret::Value.Type, nargs::Integer)
        vals = Vector{Value.Type}(nargs)
        code = [Int32[]]
        consts = TagVal[]
        return new(ret, nargs, vals, code, consts)
    end
end

function evalConst(func::Func, id)
    if id == Consts.False
        return TagVal(false)
    elseif id == Consts.True
        return TagVal(true)
    else
        return func.consts[Consts._Offset - id + 1]
    end
end

function valType(func::Func, id)
    if id >= 0
        return func.vals[id + 1]
    else
        return evalConst(func, id).typ
    end
end

function showValName(io::IO, func::Func, id)
    if id >= 0
        print(io, '%', id)
    elseif id == Consts.False
        print(io, "false")
    elseif id == Consts.True
        print(io, "true")
    else
        constval = evalConst(func, id)
        val = constval.val
        typ = constval.typ
        if typ == Value.Int32
            print(io, Int32(val))
        elseif typ == Value.Float64
            print(io, Float64(val))
        else
            print(io, "undef")
        end
    end
    return
end

function showVal(io::IO, func::Func, id)
    print(io, typeName(valType(func, id)), " ")
    showValName(io, func, id)
end

function showBB(io::IO, func::Func, bb)
    i = 1
    len = length(bb)
    while len >= i
        op = OP.Type(bb[i])
        i += 1
        if op == OP.ret
            print(io, "  ret ")
            showVal(io, func, bb[i])
            println(io)
            i += 1
        elseif op == OP.br
            cond = bb[i]
            i += 1
            bb1 = bb[i]
            i += 1
            if cond == Consts.True
                println(io, "  br L", bb1)
            else
                bb2 = bb[i]
                i += 1
                print(io, "  br ")
                showVal(io, func, cond)
                println(io, ", L", bb1, ", L", bb2)
            end
        elseif op in (OP.add, OP.sub, OP.mul, OP.fdiv)
            res = bb[i]
            i += 1
            val1 = bb[i]
            i += 1
            val2 = bb[i]
            i += 1
            print(io, "  ")
            showVal(io, func, res)
            print(io, " = ", opName(op), " ")
            showVal(io, func, val1)
            print(io, ", ")
            showVal(io, func, val2)
            println(io)
        elseif op == OP.cmp
            res = bb[i]
            i += 1
            cmptyp = Cmp.Type(bb[i])
            i += 1
            val1 = bb[i]
            i += 1
            val2 = bb[i]
            i += 1
            print(io, "  ")
            showVal(io, func, res)
            print(io, " = ", opName(op), " ", cmpName(cmptyp), " ")
            showVal(io, func, val1)
            print(io, ", ")
            showVal(io, func, val2)
            println(io)
        elseif op == OP.phi
            res = bb[i]
            i += 1
            nargs = bb[i]
            i += 1
            print(io, "  ")
            showVal(io, func, res)
            print(io, " = ", opName(op), " ")
            for j in 0:(nargs - 1)
                if j != 0
                    print(io, ", [ L")
                else
                    print(io, "[ L")
                end
                print(io, bb[i + 2 * j + 1], ": ")
                showVal(io, func, bb[i + 2 * j + 2])
                print(io, " ]")
            end
            i += 2 * nargs
            println(io)
        elseif op == OP.call
            res = bb[i]
            i += 1
            id = Builtin.Id(bb[i])
            i += 1
            nargs = bb[i]
            i += 1
            print(io, "  ")
            showVal(io, func, res)
            print(io, " = ", opName(op), " ", builtinName(id), "(")
            for j in 0:(nargs - 1)
                if j != 0
                    print(io, ", ")
                end
                showVal(io, func, bb[i + j])
            end
            i += nargs;
            println(io, ")")
        else
            println(io, "  unknown op: ", Int8(op))
        end
    end
end

function Base.show(io::IO, func::Func)
    print(io, typeName(func.ret), " (")
    for i in 0:(func.nargs - 1)
        if i != 0
            print(io, ", ")
        end
        print(io, typeName(valType(func, i)), " ")
        showValName(io, func, i);
    end
    println(io, ") {")
    code = func.code
    for i in 1:length(code)
        println(io, "L", i - 1, ":")
        showBB(io, func, code[i])
    end
    println(io, "}")
    return
end

function Base.write(io::IO, func::Func)
    # [ret][nargs][nvals][vals x nvals]
    # [nconsts][consts x nconsts]
    # [nbb][[nword][code x nword] x nbb]
    write(io, Int32(func.ret))
    write(io, Int32(func.nargs))
    copy_vector = function (vec)
        write(io, Int32(length(vec)))
        write(io, vec)
    end
    copy_vector(func.vals)
    write(io, Int32(length(func.consts)))
    for c in func.consts
        write(io, Int32(c.typ))
        write(io, reinterpret(UInt64, c.val))
    end
    write(io, Int32(length(func.code)))
    for c in func.code
        copy_vector(c)
    end
end

function Base.read(io::IO, ::Type{Func})
    ret = Value.Type(read(io, Int32))
    nargs = read(io, Int32)
    func = Func(ret, nargs)
    read_vector = function (vec)
        sz = read(io, Int32)
        resize!(vec, sz)
        read!(io, vec)
    end
    read_vector(func.vals)
    nconsts = read(io, Int32)
    consts = func.consts
    resize!(consts, nconsts)
    for i in 1:nconsts
        consts[i] = TagVal(Value.Type(read(io, Int32)),
                           reinterpret(GenVal, read(io, Int64)))
    end
    nbb = read(io, Int32)
    code = func.code
    resize!(code, nbb)
    for i in 1:nbb
        if i == 1
            bb = code[1]
        else
            bb = code[i] = Int32[]
        end
        read_vector(bb)
    end
end

type Builder
    f::Func
    cur_bb::Int
    const_ints::Dict{Int32,Int}
    const_floats::Dict{Float64,Int}
    Builder(ret::Value.Type, args) =
        new(Func(ret, args), 0, Dict{Int32,Int}(), Dict{Float64,Int}())
end

Base.get(builder::Builder) = builder.f

getConstInt(builder::Builder, val::Int32) = get!(builder.const_ints, val) do
    f = builder.f
    consts = f.consts
    oldlen = length(consts)
    push!(consts, TagVal(val))
    id = Int32(Consts._Offset - oldlen)
    builder.const_ints[val] = id
    return id
end
getConstInt(builder::Builder, val) = getConstInt(builder, Int32(val))

getConstFloat(builder::Builder, val::Float64) = get!(builder.const_floats, val) do
    f = builder.f
    consts = f.consts
    oldlen = length(consts)
    push!(consts, TagVal(val))
    id = Int32(Consts._Offset - oldlen)
    builder.const_floats[val] = id
    return id
end
getConstFloat(builder::Builder, val) = getConstFloat(builder, Float64(val))

function getConst(builder::Builder, _val::TagVal)
    typ = _val.typ
    val = _val.val
    if typ == Value.Bool
        return Bool(val) ? Consts.True : Consts.False
    elseif typ == Value.Int32
        return getConstInt(builder, Int32(val))
    elseif typ == Value.Float64
        return getConstFloat(builder, Float64(val))
    else
        return Consts.False
    end
end

curBB(builder::Builder) = builder.cur_bb
function setCurBB(builder::Builder, bb)
    builder.cur_bb = bb
    return
end

function newBB(builder::Builder)
    code = builder.f.code
    id = length(code)
    push!(code, Int32[])
    return id
end

immutable InstRef
    bb::Int
    idx::Int
end

Base.:+(ref::InstRef, offset) = InstRef(ref.bb, ref.idx + offset)

function Base.setindex!(builder::Builder, val, ref::InstRef)
    bb = builder.f.code[ref.bb + 1]
    bb[ref.idx + 1] = val
    return
end

function Base.getindex(builder::Builder, ref::InstRef)
    bb = builder.f.code[ref.bb + 1]
    return bb[ref.idx + 1]
end

function addInst(builder::Builder, op::OP.Type, nop)
    bb = builder.f.code[builder.cur_bb + 1]
    oldlen = length(bb)
    ref = InstRef(builder.cur_bb, oldlen + 1)
    resize!(bb, oldlen + nop + 1)
    bb[oldlen + 1] = Int32(op)
    return ref
end

function createRet(builder::Builder, val)
    ref = addInst(builder, OP.ret, 1)
    builder[ref] = val
    return
end

function createBr(builder::Builder, cond, bb1, bb2)
    if cond == Consts.True
        ref = addInst(builder, OP.br, 2)
    else
        ref = addInst(builder, OP.br, 3)
        builder[ref + 2] = bb2
    end
    builder[ref] = cond
    builder[ref + 1] = bb1
end
createBr(builder::Builder, bb) = createBr(builder, Consts.True, bb, 0)

@inline function evalBinOp(f, typ::Value.Type, val1, val2)
    if typ == Value.Int32
        return TagVal(f(Int32(val1), Int32(val2)))
    elseif typ == Value.Float64
        return TagVal(f(Float64(val1), Float64(val2)))
    else
        return TagVal(typ)
    end
end

function evalCmp(cmptyp::Cmp.Type, val1, val2)
    v1 = Float64(val1)
    v2 = Float64(val2)
    if cmptyp == Cmp.eq
        return TagVal(v1 == v2)
    elseif cmptyp == Cmp.gt
        return TagVal(v1 > v2)
    elseif cmptyp == Cmp.ge
        return TagVal(v1 >= v2)
    elseif cmptyp == Cmp.lt
        return TagVal(v1 < v2)
    elseif cmptyp == Cmp.le
        return TagVal(v1 <= v2)
    elseif cmptyp == Cmp.ne
        return TagVal(v1 != v2)
    else
        return TagVal(false)
    end
end

function newSSA(builder::Builder, typ::Value.Type)
    vals = builder.f.vals
    id = length(vals)
    push!(vals, typ)
    return id
end

function createPromoteOP(builder::Builder, op::OP.Type, val1, val2)
    f = builder.f
    ty1 = valType(f, val1)
    ty2 = valType(f, val2)
    resty = op == OP.fdiv ? Value.Float64 : max(ty1, ty2, Value.Int32)
    if val1 < 0 && val2 < 0
        c1 = evalConst(f, val1)
        c2 = evalConst(f, val2)
        if op == OP.add
            return getConst(builder, evalBinOP(+, resty, c1, c2))
        elseif op == OP.sub
            return getConst(builder, evalBinOP(-, resty, c1, c2))
        elseif op == OP.mul
            return getConst(builder, evalBinOP(*, resty, c1, c2))
        elseif op == OP.div
            return getConst(builder, evalBinOP(/, resty, c1, c2))
        end
    end
    ref = addInst(builder, op, 3)
    res = newSSA(builder, resty)
    builder[ref] = res
    builder[ref + 1] = val1
    builder[ref + 2] = val2
    return res
end

createAdd(builder::Builder, val1, val2) =
    createPromoteOP(builder, OP.add, val1, val2)
createSub(builder::Builder, val1, val2) =
    createPromoteOP(builder, OP.sub, val1, val2)
createMul(builder::Builder, val1, val2) =
    createPromoteOP(builder, OP.mul, val1, val2)
createFDiv(builder::Builder, val1, val2) =
    createPromoteOP(builder, OP.fdiv, val1, val2)

function createCmp(builder::Builder, cmp::Cmp.Type, val1, val2)
    if val1 < 0 && val2 < 0
        return getConst(builder, evalCmp(cmp, evalConst(f, val1),
                                         evalConst(f, val2)))
    end
    ref = addInst(builder, OP.cmp, 4)
    res = newSSA(builder, Value.Bool)
    builder[res] = res
    builder[res + 1] = cmp
    builder[res + 2] = val1
    builder[res + 3] = val2
    return res;
end

function createPhi(builder::Builder, typ::Value.Type, ninputs)
    ref = addInst(builder, OP.phi, ninputs * 2 + 2)
    res = newSSA(builder, typ)
    builder[ref] = res
    builder[ref + 1] = ninputs
    bb = builder.f.code[ref.bb + 1]
    ccall(:memset, Ptr{Void}, (Ptr{Int32}, Cint, Csize_t),
          pointer(bb, ref.idx + 3), 0xff, sizeof(Int32) * 2 * ninputs)
    return res, ref
end

function addPhiInput(builder::Builder, ref, bb, val)
    code = builder.f.code[ref.bb + 1]
    offset = ref.idx
    nargs = code[offset + 2]
    for i in 1:nargs
        bb1 = code[2i + offset + 1]
        if bb1 == bb || bb1 == -1
            code[2i + offset + 1] = bb
            code[2i + offset + 2] = val
            break
        end
    end
end

function createCall(builder::Builder, id::Builtin.Id, args)
    nargs = length(args)
    calltyp = getBuiltinType(id)
    if calltyp == Builtin.F64_F64
        if nargs != 1
            return getConstFloat(builder, 0)
        end
    elseif (calltyp == Builtin.F64_F64F64 || calltyp == Builtin.F64_F64I32 ||
            calltyp == Builtin.F64_I32F64)
        if nargs != 2
            return getConstFloat(builder, 0)
        end
    elseif calltyp == Builtin.F64_F64F64F64
        if nargs != 3
            return getConstFloat(builder, 0)
        end
    else
        return getConstFloat(builder, 0)
    end
    allconst = true
    for arg in args
        if arg >= 0
            allconst = false
            break
        end
    end
    if allconst
        carg1 = TagVal()
        carg2 = TagVal()
        carg3 = TagVal()
        f = builder.f
        carg1 = evalConst(f, args[1])
        if nargs == 2
            carg2 = evalConst(f, args[2])
        elseif nargs == 3
            carg2 = evalConst(f, args[2])
            carg3 = evalConst(f, args[3])
        end
        return getConstFloat(builder, evalBuiltin(id, (carg1, carg2, carg3)))
    end
    ref = addInst(builder, OP.call, nargs + 3)
    res = newSSA(builder, Value.Float64)
    builder[ref] = res
    builder[ref + 1] = Int32(id)
    builder[ref + 2] = nargs
    for i in 1:nargs
        builder[ref + 2 + i] = args[i]
    end
    return res
end

# struct NACS_EXPORT EvalContext {
#     EvalContext(const Function &f)
#         : m_f(f),
#           m_vals(f.vals.size())
#     {}
#     void reset(GenVal *args)
#     {
#         memcpy(m_vals.data(), args, m_f.nargs * sizeof(GenVal));
#     }
#     void reset(std::vector<TagVal> tagvals)
#     {
#         std::vector<GenVal> args(m_f.nargs);
#         for (int i = 0;i < m_f.nargs;i++)
#             args[i] = tagvals[i].convert(m_f.vals[i]).val;
#         reset(args.data());
#     }
#     void reset(int idx, const GenVal &arg)
#     {
#         m_vals[idx] = arg;
#     }
#     TagVal evalVal(int32_t id) const;
#     TagVal eval(void);

# private:
#     const Function &m_f;
#     std::vector<GenVal> m_vals;
# };

# TagVal EvalContext::evalVal(int32_t id) const
# {
#     if (id >= 0) {
#         return TagVal(m_f.vals[id], m_vals[id]);
#     } else {
#         return m_f.evalConst(id);
#     }
# }

# TagVal EvalContext::eval(void)
# {
#     int32_t bb_num = -1;
#     int32_t prev_bb_num;
#     const int32_t *pc;
#     const int32_t *end;
#     auto enter_bb = [&] (int32_t i) {
#         prev_bb_num = bb_num;
#         bb_num = i;
#         auto &bb = m_f.code[i];
#         pc = bb.data();
#         end = pc + bb.size();
#     };
#     enter_bb(0);

#     while (end > pc) {
#         auto op = Opcode(*pc);
#         pc++;
#         auto res = *pc;
#         pc++;
#         auto &res_slot = m_vals[res];
#         switch (op) {
#         case Opcode::Ret:
#             return evalVal(res).convert(m_f.ret);
#         case Opcode::Br:
#             if (evalVal(res).get<bool>()) {
#                 enter_bb(pc[0]);
#             } else {
#                 enter_bb(pc[1]);
#             }
#             continue;
#         case Opcode::Add:
#         case Opcode::Sub:
#         case Opcode::Mul:
#         case Opcode::FDiv: {
#             auto val1 = evalVal(*pc);
#             pc++;
#             auto val2 = evalVal(*pc);
#             pc++;
#             switch (op) {
#             case Opcode::Add:
#                 res_slot = evalAdd(m_f.vals[res], val1, val2).val;
#                 break;
#             case Opcode::Sub:
#                 res_slot = evalSub(m_f.vals[res], val1, val2).val;
#                 break;
#             case Opcode::Mul:
#                 res_slot = evalMul(m_f.vals[res], val1, val2).val;
#                 break;
#             case Opcode::FDiv:
#                 res_slot = evalFDiv(val1, val2).val;
#                 break;
#             default:
#                 break;
#             }
#             break;
#         }
#         case Opcode::Cmp: {
#             auto cmptyp = CmpType(*pc);
#             pc++;
#             auto val1 = evalVal(*pc);
#             pc++;
#             auto val2 = evalVal(*pc);
#             pc++;
#             res_slot = evalCmp(cmptyp, val1, val2).val;
#             break;
#         }
#         case Opcode::Phi: {
#             auto nargs = *pc;
#             pc++;
#             auto args = pc;
#             pc += 2 * nargs;
#             for (int i = 0;i < nargs;i++) {
#                 if (args[2 * i] == prev_bb_num) {
#                     auto val = evalVal(args[2 * i + 1]);
#                     res_slot = val.convert(m_f.vals[res]).val;
#                     break;
#                 }
#             }
#             break;
#         }
#         case Opcode::Call: {
#             auto id = Builtins(*pc);
#             pc++;
#             auto nargs = *pc;
#             pc++;
#             TagVal argvals[3];
#             assert(nargs <= 3);
#             for (int i = 0;i < nargs;i++)
#                 argvals[i] = evalVal(pc[i]);
#             pc += nargs;
#             res_slot = TagVal(evalBuiltin(id, argvals)).val;
#             break;
#         }
#         default:
#             break;
#         }
#     }
#     return TagVal(m_f.ret);
# }

end
