#!/usr/bin/julia -f
# Copyright (c) 2016-2016, Yichao Yu <yyc1992@gmail.com>
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

immutable NullRef{T}
    x::T
    NullRef() = new()
    NullRef(x) = new(x)
end
NullRef{T}(x::T) = NullRef{T}(x)
@inline Base.isnull(x::NullRef) = !isdefined(x, :x)
@inline Base.get(x::NullRef) = x.x

abstract NamedConsts{T}

function get_inttype(sz)
    if sz == 8
        return Int8
    elseif sz == 16
        return Int16
    elseif sz == 32
        return Int32
    elseif sz == 64
        return Int64
    elseif sz == 128
        return Int128
    else
        throw(ArgumentError("Illegal size $sz"))
    end
end
Base.@pure function get_inttype{T<:NamedConsts}(::Type{T})
    return get_inttype(sizeof(T) * 8)
end

@noinline function throw_convert_error{T}(::Type{T})
    throw(ArgumentError("invalid value for $T"))
end

function constname end
validate{Ti}(x::NamedConsts{Ti}) = validate(typeof(x), reinterpret(Ti, x))

Base.convert{T<:Integer,Ti}(::Type{T}, x::NamedConsts{Ti})::T =
    reinterpret(Ti, x)
Base.write{Ti}(io::IO, x::NamedConsts{Ti}) = write(io, convert(Ti, x))
Base.read{T<:NamedConsts}(io::IO, ::Type{T}) = T(read(io, get_inttype(T)))
function Base.convert{T<:NamedConsts}(::Type{T}, _x::Integer)
    Ti = get_inttype(T)
    x = convert(Ti, _x)::Ti
    validate(T, x) || throw_convert_error(T)
    return reinterpret(T, x)
end
function Base.isless{T<:NamedConsts}(v1::T, v2::T)
    Ti = get_inttype(T)
    return isless(reinterpret(Ti, v1), reinterpret(Ti, v2))
end
function Base.print(io::IO, x::NamedConsts)
    print(io, constname(x))
    return
end
function Base.show(io::IO, x::NamedConsts)
    if get(io, :compact, false)
        print(io, x)
    else
        print(io, x, "::")
        Base.showcompact(io, typeof(x))
        print(io, " = ", Int(x))
    end
end
@inline Base.:(==){Ti}(x::NamedConsts{Ti}, y::Integer) =
    reinterpret(Ti, x) == y
@inline Base.:(==){Ti}(y::Integer, x::NamedConsts{Ti}) =
    reinterpret(Ti, x) == y
@inline Base.hash{Ti}(x::NamedConsts{Ti}, h::UInt) = hash(reinterpret(Ti,x), h)
@inline Base.:+{Ti}(x::NamedConsts{Ti}, y::Integer) =
    reinterpret(Ti, x) + y
@inline Base.:+{Ti}(y::Integer, x::NamedConsts{Ti}) =
    reinterpret(Ti, x) + y
@inline Base.:-{Ti}(x::NamedConsts{Ti}, y::Integer) =
    reinterpret(Ti, x) - y
@inline Base.:-{Ti}(y::Integer, x::NamedConsts{Ti}) =
    y - reinterpret(Ti, x)

function get_constval(T, Ti, _val, set)
    val = Ti(_val)::Ti
    cval = reinterpret(T, val)
    push!(set, cval)
    return cval
end

function get_checkfunc{Ti}(T, ::Type{Ti}, set)
    vec = sort!(Ti[reinterpret(Ti, v)::Ti for v in set])
    tmax = vec[end]
    tmin = vec[1]
    common_expr = quote
        $Base.@inline function $Base.typemin(::$Base.Type{$T})
            return $(reinterpret(T, tmin))
        end
        $Base.@inline function $Base.typemax(::$Base.Type{$T})
            return $(reinterpret(T, tmax))
        end
        $Base.@inline function $Base.instances(::$Base.Type{$T})
            return ($((reinterpret(T, v) for v in vec)...),)
        end
    end
    # Fast path
    if length(vec) - 1 == tmax - tmin
        return quote
            $common_expr
            $Base.@inline function $thismodule.validate(::$Base.Type{$T},
                                                       val::$Base.Integer)
                return $Base.:<=($tmin, val) && $Base.:<=(val, $tmax)
            end
        end
    end
    start_v = prev_v = vec[1]
    ranges = NTuple{2,Ti}[]
    for i in 2:length(vec)
        v = vec[i]
        if v - prev_v == 1
            prev_v = v
            continue
        end
        push!(ranges, (start_v, prev_v))
        start_v = prev_v = v
    end
    push!(ranges, (start_v, prev_v))
    return quote
        $common_expr
        $Base.@inline function $thismodule.validate(::$Base.Type{$T},
                                                    val::$Base.Integer)
            $((r[1] == r[2] ? :($Base.:(==)(val, $(r[1])) && return true) :
               :($Base.:<=($(r[1]), val) && $Base.:<=(val, $(r[2])) &&
                 return true)
               for r in ranges)...)
            return false
        end
    end
end

const thismodule = current_module()
macro named_consts(sz, typename, vals...)
    if Meta.isexpr(sz, :parameters)
        throw(ArgumentError("@named_consts does not accept keyword arguments"))
    end
    if isempty(vals)
        throw(ArgumentError("Names can't be empty"))
    end
    if !isa(typename, Symbol)
        throw(ArgumentError("Type name must be a symbol"))
    end
    @gensym inttype
    ex = quote
        const $inttype = get_inttype($(esc(sz)))
        $(Expr(:meta, :doc))
        bitstype sizeof($inttype) * 8 $(esc(typename)) <: NamedConsts{$inttype}
    end
    names = Symbol[]
    base_var = 0
    offset = 0
    valset = Set{Any}()
    constargs = []
    # Values
    for val in vals
        if isa(val, Symbol)
            val = val::Symbol
            name = val
        elseif isa(val, Expr)
            val = val::Expr
            head = val.head
            if !((head === :(=) || head === :kw) && length(val.args) == 2)
                throw(ArgumentError("Unknown argument $val"))
            end
            name = val.args[1]
            if !isa(name, Symbol)
                throw(ArgumentError("Name ($name) must be a symbol."))
            end
            name = name::Symbol
            v = val.args[2]
            @gensym vname
            push!(constargs, :(const $vname = $(esc(v))))
            base_var = vname
            offset = 0
        else
            throw(ArgumentError("Unknown argument $val"))
        end
        push!(names, name)
        push!(constargs, :(const $(esc(name)) = get_constval($(esc(typename)),
                                                             $inttype,
                                                             $base_var + $offset,
                                                             $valset)))
        offset += 1
    end
    # name
    funcs_expr = quote
        function $thismodule.constname(x::$(esc(typename)))
            $((:(x === $(esc(name)) && return $(QuoteNode(name))) for name in names)...)
            return $(QuoteNode(Symbol("")))
        end
        function $(esc(typename))(_x::Integer)
            x = convert($inttype, _x)::$inttype
            return reinterpret($(esc(typename)), x)
        end
        $(constargs...)
        $Core.eval(current_module(),
                   get_checkfunc($(esc(typename)), $inttype, $valset))
    end
    append!(ex.args, funcs_expr.args)
    ex
end
