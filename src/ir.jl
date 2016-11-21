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

# struct Function {
#     typedef std::vector<int32_t> BB;
#     typedef std::pair<int32_t, int32_t> InstRef;
#     Function(Type _ret, const std::vector<Type> &args)
#         : ret(_ret),
#           nargs((int)args.size()),
#           vals(args),
#           code{BB{}},
#           consts{}
#     {}
#     Function(const uint32_t*, size_t);
#     Function(const std::vector<uint32_t> &data)
#         : Function(data.data(), data.size())
#     {}
#     void dump(void) const;
#     Type valType(int32_t id) const;
#     TagVal evalConst(int32_t id) const
#     {
#         assert(id < 0);
#         if (id == Consts::False) {
#             return false;
#         } else if (id == Consts::True) {
#             return true;
#         } else {
#             return consts[Consts::_Offset - id];
#         }
#     }
#     std::vector<uint32_t> serialize(void) const;
#     const Type ret;
#     const int nargs;
#     std::vector<Type> vals;
#     std::vector<BB> code;
#     std::vector<TagVal> consts;
# private:
#     void dumpValName(int32_t id) const;
#     void dumpVal(int32_t id) const;
#     void dumpBB(const BB&) const;
# };

# class NACS_EXPORT Builder {
# public:
#     Builder(Type ret, std::vector<Type> args)
#         : m_f(ret, args),
#           m_cur_bb(0),
#           const_ints{},
#           const_floats{}
#     {}
#     Function &get(void)
#     {
#         return m_f;
#     }
#     int32_t getConst(TagVal val);
#     int32_t getConstInt(int32_t val);
#     int32_t getConstFloat(double val);

#     int32_t newBB(void);
#     int32_t &curBB(void);

#     void createRet(int32_t val);
#     void createBr(int32_t br);
#     void createBr(int32_t cond, int32_t bb1, int32_t bb2);
#     int32_t createAdd(int32_t val1, int32_t val2);
#     int32_t createSub(int32_t val1, int32_t val2);
#     int32_t createMul(int32_t val1, int32_t val2);
#     int32_t createFDiv(int32_t val1, int32_t val2);
#     int32_t createCmp(CmpType cmptyp, int32_t val1, int32_t val2);
#     std::pair<int32_t, Function::InstRef> createPhi(Type typ, int ninputs);
#     void addPhiInput(Function::InstRef phi, int32_t bb, int32_t val);
#     int32_t createCall(Builtins id, int32_t nargs, const int32_t *args);
#     int32_t createCall(Builtins id, const std::vector<int32_t> &args)
#     {
#         return createCall(id, (int32_t)args.size(), args.data());
#     }
# private:
#     int32_t *addInst(Opcode op, size_t nop);
#     int32_t *addInst(Opcode op, size_t nop, Function::InstRef &inst);
#     int32_t newSSA(Type typ);
#     int32_t createPromoteOP(Opcode op, int32_t val1, int32_t val2);
#     Function m_f;
#     int32_t m_cur_bb;
#     std::map<int32_t, int> const_ints;
#     std::map<double, int> const_floats;
# };

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

# NACS_EXPORT void TagVal::dump(void) const
# {
#     std::cout << typeName(typ) << " ";
#     switch (typ) {
#     case Type::Bool:
#         std::cout << (val.b ? "true" : "false");
#         break;
#     case Type::Int32:
#         std::cout << val.i32;
#         break;
#     case Type::Float64:
#         std::cout << val.f64;
#         break;
#     default:
#         std::cout << "undef";
#     }
#     std::cout << std::endl;
# }

# void Function::dumpValName(int32_t id) const
# {
#     if (id >= 0) {
#         std::cout << "%" << id;
#     } else if (id == Consts::False) {
#         std::cout << "false";
#     } else if (id == Consts::True) {
#         std::cout << "true";
#     } else {
#         auto &constval = consts[Consts::_Offset - id];
#         auto val = constval.val;
#         switch (constval.typ) {
#         case Type::Int32:
#             std::cout << val.i32;
#             break;
#         case Type::Float64:
#             std::cout << val.f64;
#             break;
#         default:
#             std::cout << "undef";
#         }
#     }
# }

# NACS_EXPORT Type Function::valType(int32_t id) const
# {
#     if (id >= 0) {
#         return vals[id];
#     } else if (id == Consts::False || id == Consts::True) {
#         return Type::Bool;
#     } else {
#         return consts[Consts::_Offset - id].typ;
#     }
# }

# void Function::dumpVal(int32_t id) const
# {
#     std::cout << typeName(valType(id)) << " ";
#     dumpValName(id);
# }

# void Function::dumpBB(const BB &bb) const
# {
#     const int32_t *pc = bb.data();
#     const int32_t *end = pc + bb.size();
#     while (end > pc) {
#         auto op = Opcode(*pc);
#         pc++;
#         switch (op) {
#         case Opcode::Ret:
#             std::cout << "  ret ";
#             dumpVal(*pc);
#             std::cout << std::endl;
#             pc++;
#             break;
#         case Opcode::Br: {
#             auto cond = *pc;
#             pc++;
#             auto bb1 = *pc;
#             pc++;
#             if (cond == Consts::True) {
#                 std::cout << "  br L" << bb1;
#             } else {
#                 auto bb2 = *pc;
#                 pc++;
#                 std::cout << "  br ";
#                 dumpVal(cond);
#                 std::cout << ", L" << bb1 << ", L" << bb2;
#             }
#             std::cout << std::endl;
#             break;
#         }
#         case Opcode::Add:
#         case Opcode::Sub:
#         case Opcode::Mul:
#         case Opcode::FDiv: {
#             auto res = *pc;
#             pc++;
#             auto val1 = *pc;
#             pc++;
#             auto val2 = *pc;
#             pc++;
#             std::cout << "  ";
#             dumpVal(res);
#             std::cout << " = " << opName(op) << " ";
#             dumpVal(val1);
#             std::cout << ", ";
#             dumpVal(val2);
#             std::cout << std::endl;
#             break;
#         }
#         case Opcode::Cmp: {
#             auto res = *pc;
#             pc++;
#             auto cmptyp = CmpType(*pc);
#             pc++;
#             auto val1 = *pc;
#             pc++;
#             auto val2 = *pc;
#             pc++;
#             std::cout << "  ";
#             dumpVal(res);
#             std::cout << " = " << opName(op) << " " << cmpName(cmptyp) << " ";
#             dumpVal(val1);
#             std::cout << ", ";
#             dumpVal(val2);
#             std::cout << std::endl;
#             break;
#         }
#         case Opcode::Phi: {
#             auto res = *pc;
#             pc++;
#             auto nargs = *pc;
#             pc++;
#             std::cout << "  ";
#             dumpVal(res);
#             std::cout << " = " << opName(op) << " ";
#             for (int i = 0;i < nargs;i++) {
#                 if (i != 0) {
#                     std::cout << ", [ L";
#                 } else {
#                     std::cout << "[ L";
#                 }
#                 std::cout << pc[2 * i] << ": ";
#                 dumpVal(pc[2 * i + 1]);
#                 std::cout << " ]";
#             }
#             pc += 2 * nargs;
#             std::cout << std::endl;
#             break;
#         }
#         case Opcode::Call: {
#             auto res = *pc;
#             pc++;
#             auto id = Builtins(*pc);
#             pc++;
#             auto nargs = *pc;
#             pc++;
#             std::cout << "  ";
#             dumpVal(res);
#             std::cout << " = " << opName(op) << " " << builtinName(id) << "(";
#             for (int i = 0;i < nargs;i++) {
#                 if (i != 0) {
#                     std::cout << ", ";
#                 }
#                 dumpVal(pc[i]);
#             }
#             pc += nargs;
#             std::cout << ")" << std::endl;
#             break;
#         }
#         default:
#             std::cout << "  unknown op: " << uint8_t(op) << std::endl;
#             break;
#         }
#     }
# }

# NACS_EXPORT void Function::dump(void) const
# {
#     std::cout << typeName(ret) << " (";
#     for (int i = 0;i < nargs;i++) {
#         if (i != 0)
#             std::cout << ", ";
#         std::cout << typeName(valType(i)) << " ";
#         dumpValName(i);
#     }
#     std::cout << ") {" << std::endl;
#     for (size_t i = 0;i < code.size();i++) {
#         std::cout << "L" << i << ":" << std::endl;
#         dumpBB(code[i]);
#     }
#     std::cout << "}" << std::endl;
# }

# NACS_EXPORT std::vector<uint32_t> Function::serialize(void) const
# {
#     // [ret][nargs][nvals][vals x nvals]
#     // [nconsts][consts x nconsts]
#     // [nbb][[nword][code x nword] x nbb]
#     std::vector<uint32_t> res{uint32_t(ret), uint32_t(nargs)};
#     auto copy_vector = [&res] (auto vec) {
#         res.push_back(uint32_t(vec.size()));
#         uint32_t idx = (uint32_t)res.size();
#         size_t elsz = sizeof(typename decltype(vec)::value_type);
#         res.resize(idx + (vec.size() * elsz + 3) / 4);
#         memcpy(&res[idx], vec.data(), vec.size() * elsz);
#     };
#     copy_vector(vals);
#     {
#         res.push_back(uint32_t(consts.size()));
#         uint32_t idx = (uint32_t)res.size();
#         res.resize(idx + consts.size() * 3);
#         for (size_t i = 0;i < consts.size();i++) {
#             res[idx + i * 3] = uint32_t(consts[i].typ);
#             memcpy(&res[idx + i * 3 + 1], &(consts[i].val), sizeof(GenVal));
#         }
#     }
#     res.push_back(uint32_t(code.size()));
#     for (size_t i = 0;i < code.size();i++)
#         copy_vector(code[i]);
#     return res;
# }

# NACS_EXPORT Function::Function(const uint32_t *data, size_t)
#     : ret(Type(data[0])),
#       nargs(data[1]),
#       vals{},
#       code{},
#       consts{}
# {
#     uint32_t cursor = 2;
#     auto read_vector = [data, &cursor] (auto &vec) {
#         uint32_t size = data[cursor];
#         cursor++;
#         vec.resize(size);
#         int32_t elsz = sizeof(typename std::remove_reference_t<
#                               decltype(vec)>::value_type);
#         memcpy(vec.data(), &data[cursor], size * elsz);
#         cursor += (size * elsz + 3) / 4;
#     };
#     read_vector(vals);
#     {
#         uint32_t size = data[cursor];
#         cursor++;
#         consts.resize(size);
#         for (size_t i = 0;i < size;i++) {
#             consts[i].typ = Type(data[cursor + i * 3]);
#             memcpy(&(consts[i].val), &data[cursor + i * 3 + 1], 8);
#         }
#         cursor += size * 3;
#     }
#     code.resize(data[cursor]);
#     cursor++;
#     for (size_t i = 0;i < code.size();i++) {
#         read_vector(code[i]);
#     }
# }

# int32_t *Builder::addInst(Opcode op, size_t nop)
# {
#     Function::InstRef inst;
#     return addInst(op, nop, inst);
# }

# int32_t *Builder::addInst(Opcode op, size_t nop, Function::InstRef &inst)
# {
#     auto &bb = m_f.code[m_cur_bb];
#     auto oldlen = (int32_t)bb.size();
#     inst.first = m_cur_bb;
#     inst.second = oldlen + 1;
#     bb.resize(oldlen + nop + 1);
#     bb[oldlen] = uint32_t(op);
#     return &bb[oldlen + 1];
# }

# void Builder::createRet(int32_t val)
# {
#     *addInst(Opcode::Ret, 1) = val;
# }

# int32_t Builder::getConstInt(int32_t val)
# {
#     auto map = const_ints;
#     auto it = map.find(val);
#     if (it != map.end())
#         return it->second;
#     int32_t oldlen = (int32_t)m_f.consts.size();
#     m_f.consts.emplace_back(val);
#     int32_t id = Consts::_Offset - oldlen;
#     map[val] = id;
#     return id;
# }

# int32_t Builder::getConstFloat(double val)
# {
#     auto map = const_floats;
#     auto it = map.find(val);
#     if (it != map.end())
#         return it->second;
#     int32_t oldlen = (int32_t)m_f.consts.size();
#     m_f.consts.emplace_back(val);
#     int32_t id = Consts::_Offset - oldlen;
#     map[val] = id;
#     return id;
# }

# int32_t Builder::getConst(TagVal val)
# {
#     switch (val.typ) {
#     case Type::Bool:
#         return val.val.b ? Consts::True : Consts::False;
#     case Type::Int32:
#         return getConstInt(val.val.i32);
#     case Type::Float64:
#         return getConstFloat(val.val.f64);
#     default:
#         return Consts::False;
#     }
# }

# int32_t Builder::newSSA(Type typ)
# {
#     int32_t id = (int32_t)m_f.vals.size();
#     m_f.vals.push_back(typ);
#     return id;
# }

# int32_t Builder::newBB(void)
# {
#     int32_t id = (int32_t)m_f.code.size();
#     m_f.code.push_back({});
#     return id;
# }

# int32_t &Builder::curBB()
# {
#     return m_cur_bb;
# }

# void Builder::createBr(int32_t br)
# {
#     createBr(Consts::True, br, 0);
# }

# void Builder::createBr(int32_t cond, int32_t bb1, int32_t bb2)
# {
#     if (cond == Consts::True) {
#         int32_t *ptr = addInst(Opcode::Br, 2);
#         ptr[0] = Consts::True;
#         ptr[1] = bb1;
#     }
#     else {
#         int32_t *ptr = addInst(Opcode::Br, 3);
#         ptr[0] = cond;
#         ptr[1] = bb1;
#         ptr[2] = bb2;
#     }
# }

# static TagVal evalAdd(Type typ, TagVal val1, TagVal val2)
# {
#     switch (typ) {
#     case Type::Int32:
#         return val1.get<int32_t>() + val2.get<int32_t>();
#     case Type::Float64:
#         return val1.get<double>() + val2.get<double>();
#     default:
#         return TagVal(typ);
#     }
# }

# static TagVal evalSub(Type typ, TagVal val1, TagVal val2)
# {
#     switch (typ) {
#     case Type::Int32:
#         return val1.get<int32_t>() - val2.get<int32_t>();
#     case Type::Float64:
#         return val1.get<double>() - val2.get<double>();
#     default:
#         return TagVal(typ);
#     }
# }

# static TagVal evalMul(Type typ, TagVal val1, TagVal val2)
# {
#     switch (typ) {
#     case Type::Int32:
#         return val1.get<int32_t>() * val2.get<int32_t>();
#     case Type::Float64:
#         return val1.get<double>() * val2.get<double>();
#     default:
#         return TagVal(typ);
#     }
# }

# static TagVal evalFDiv(TagVal val1, TagVal val2)
# {
#     return val1.get<double>() / val2.get<double>();
# }

# static TagVal evalCmp(CmpType cmptyp, TagVal val1, TagVal val2)
# {
#     double v1 = val1.get<double>();
#     double v2 = val2.get<double>();
#     switch (cmptyp) {
#     case CmpType::eq:
#         return v1 == v2;
#     case CmpType::gt:
#         return v1 > v2;
#     case CmpType::ge:
#         return v1 >= v2;
#     case CmpType::lt:
#         return v1 < v2;
#     case CmpType::le:
#         return v1 <= v2;
#     case CmpType::ne:
#         return v1 != v2;
#     default:
#         return false;
#     }
# }

# int32_t Builder::createPromoteOP(Opcode op, int32_t val1, int32_t val2)
# {
#     auto ty1 = m_f.valType(val1);
#     auto ty2 = m_f.valType(val2);
#     auto resty = std::max(std::max(ty1, ty2), Type::Int32);
#     if (val1 < 0 && val2 < 0) {
#         switch (op) {
#         case Opcode::Add:
#             return getConst(evalAdd(resty, m_f.evalConst(val1),
#                                     m_f.evalConst(val2)));
#         case Opcode::Sub:
#             return getConst(evalSub(resty, m_f.evalConst(val1),
#                                     m_f.evalConst(val2)));
#         case Opcode::Mul:
#             return getConst(evalMul(resty, m_f.evalConst(val1),
#                                     m_f.evalConst(val2)));
#         default:
#             break;
#         }
#     }
#     int32_t *ptr = addInst(op, 3);
#     auto res = newSSA(resty);
#     ptr[0] = res;
#     ptr[1] = val1;
#     ptr[2] = val2;
#     return res;
# }

# int32_t Builder::createAdd(int32_t val1, int32_t val2)
# {
#     return createPromoteOP(Opcode::Add, val1, val2);
# }

# int32_t Builder::createSub(int32_t val1, int32_t val2)
# {
#     return createPromoteOP(Opcode::Sub, val1, val2);
# }

# int32_t Builder::createMul(int32_t val1, int32_t val2)
# {
#     return createPromoteOP(Opcode::Mul, val1, val2);
# }

# int32_t Builder::createFDiv(int32_t val1, int32_t val2)
# {
#     if (val1 < 0 && val2 < 0)
#         return getConst(evalFDiv(m_f.evalConst(val1), m_f.evalConst(val2)));
#     int32_t *ptr = addInst(Opcode::FDiv, 3);
#     auto res = newSSA(Type::Float64);
#     ptr[0] = res;
#     ptr[1] = val1;
#     ptr[2] = val2;
#     return res;
# }

# int32_t Builder::createCmp(CmpType cmptyp, int32_t val1, int32_t val2)
# {
#     if (val1 < 0 && val2 < 0)
#         return getConst(evalCmp(cmptyp, m_f.evalConst(val1),
#                                 m_f.evalConst(val2)));
#     int32_t *ptr = addInst(Opcode::Cmp, 4);
#     auto res = newSSA(Type::Bool);
#     ptr[0] = res;
#     ptr[1] = uint32_t(cmptyp);
#     ptr[2] = val1;
#     ptr[3] = val2;
#     return res;
# }

# std::pair<int32_t, Function::InstRef> Builder::createPhi(Type typ, int ninputs)
# {
#     Function::InstRef inst;
#     int32_t *ptr = addInst(Opcode::Phi, ninputs * 2 + 2, inst);
#     auto res = newSSA(typ);
#     ptr[0] = res;
#     ptr[1] = ninputs;
#     memset(&ptr[2], 0xff, ninputs * 2 * 4);
#     return std::make_pair(res, inst);
# }

# int32_t Builder::createCall(Builtins id, int32_t nargs, const int32_t *args)
# {
#     switch (getBuiltinType(id)) {
#     case BuiltinType::F64_F64:
#         if (nargs != 1)
#             return getConstFloat(0);
#         break;
#     case BuiltinType::F64_F64F64:
#         if (nargs != 2)
#             return getConstFloat(0);
#         break;
#     case BuiltinType::F64_F64F64F64:
#         if (nargs != 3)
#             return getConstFloat(0);
#         break;
#     case BuiltinType::F64_F64I32:
#         if (nargs != 2)
#             return getConstFloat(0);
#         break;
#     case BuiltinType::F64_I32F64:
#         if (nargs != 2)
#             return getConstFloat(0);
#         break;
#     default:
#         return getConstFloat(0);
#     }
#     bool allconst = true;
#     for (int i = 0;i < nargs;i++) {
#         if (args[i] >= 0) {
#             allconst = false;
#             break;
#         }
#     }
#     if (allconst) {
#         TagVal constargs[3];
#         assert(nargs <= 3);
#         for (int i = 0;i < nargs;i++)
#             constargs[i] = m_f.evalConst(args[i]);
#         return getConstFloat(evalBuiltin(id, constargs));
#     }
#     int32_t *ptr = addInst(Opcode::Call, nargs + 3);
#     auto res = newSSA(Type::Float64);
#     ptr[0] = res;
#     ptr[1] = uint32_t(id);
#     ptr[2] = nargs;
#     memcpy(&ptr[3], args, nargs * 4);
#     return res;
# }

# void Builder::addPhiInput(Function::InstRef phi, int32_t bb, int32_t val)
# {
#     int32_t *inst = &m_f.code[phi.first][phi.second];
#     int32_t nargs = inst[1];
#     for (int32_t i = 0;i < nargs;i++) {
#         if (inst[2 + 2 * i] == bb || inst[2 + 2 * i] == -1) {
#             inst[2 + 2 * i] = bb;
#             inst[2 + 2 * i + 1] = val;
#             break;
#         }
#     }
# }

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
