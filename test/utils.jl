#

import NaCsCtl: @named_consts, validate, constname

@named_consts 8 T8 A8 B8 C8=B8 + 3 D8=1 + C8
@testset "Size 8" begin
    @test sizeof(T8) == 1
    @test A8::T8 == 0
    @test B8::T8 == 1
    @test C8::T8 == 4
    @test D8::T8 == 5
    @test typemin(T8) === A8
    @test typemax(T8) === D8
    @test instances(T8) == (A8, B8, C8, D8)

    @test validate(A8)
    @test validate(B8)
    @test validate(C8)
    @test validate(D8)

    @test validate(T8, 0)
    @test validate(T8, 1)
    @test validate(T8, 4)
    @test validate(T8, 5)

    @test !validate(T8(2))
    @test !validate(T8(3))
    @test !validate(T8(-1))
    @test !validate(T8(6))

    @test constname(A8) === :A8
    @test constname(B8) === :B8
    @test constname(C8) === :C8
    @test constname(D8) === :D8
    @test constname(T8(-1)) === Symbol("")
end

@named_consts(16, T16, A16, B16, C16=B16 - 10 + sizeof(T16), D16)
@testset "Size 16" begin
    @test sizeof(T16) == 2
    @test A16::T16 == 0
    @test B16::T16 == 1
    @test C16::T16 == -7
    @test D16::T16 == -6
    @test typemin(T16) === C16
    @test typemax(T16) === B16
    @test instances(T16) == (C16, D16, A16, B16)

    @test validate(A16)
    @test validate(B16)
    @test validate(C16)
    @test validate(D16)

    @test validate(T16, 0)
    @test validate(T16, 1)
    @test validate(T16, -7)
    @test validate(T16, -6)

    @test !validate(T16(2))
    @test !validate(T16(-1))
    @test !validate(T16(-8))
    @test !validate(T16(-5))

    @test constname(A16) === :A16
    @test constname(B16) === :B16
    @test constname(C16) === :C16
    @test constname(D16) === :D16
    @test constname(T16(2)) === Symbol("")
end

t32_size = 4
@named_consts t32_size * 8 T32 A32 B32 C32=Int(B32) + sizeof(T32) D32
@testset "Size 32" begin
    @test sizeof(T32) == 4
    @test A32::T32 == 0
    @test B32::T32 == 1
    @test C32::T32 == 5
    @test D32::T32 == 6
    @test typemin(T32) === A32
    @test typemax(T32) === D32
    @test instances(T32) == (A32, B32, C32, D32)

    @test validate(A32)
    @test validate(B32)
    @test validate(C32)
    @test validate(D32)

    @test validate(T32, 0)
    @test validate(T32, 1)
    @test validate(T32, 5)
    @test validate(T32, 6)

    @test !validate(T32(-1))
    @test !validate(T32(2))
    @test !validate(T32(4))
    @test !validate(T32(7))

    @test constname(A32) === :A32
    @test constname(B32) === :B32
    @test constname(C32) === :C32
    @test constname(D32) === :D32
    @test constname(T32(2)) === Symbol("")
end

@named_consts sizeof(T32) * 2 * 8 T64 A64 B64 C64=sizeof(T64) - B64 D64
@testset "Size 64" begin
    @test sizeof(T64) == 8
    @test A64::T64 == 0
    @test B64::T64 == 1
    @test C64::T64 == 7
    @test D64::T64 == 8
    @test typemin(T64) === A64
    @test typemax(T64) === D64
    @test instances(T64) == (A64, B64, C64, D64)

    @test validate(A64)
    @test validate(B64)
    @test validate(C64)
    @test validate(D64)

    @test validate(T64, 0)
    @test validate(T64, 1)
    @test validate(T64, 7)
    @test validate(T64, 8)

    @test !validate(T64(-1))
    @test !validate(T64(2))
    @test !validate(T64(6))
    @test !validate(T64(9))

    @test constname(A64) === :A64
    @test constname(B64) === :B64
    @test constname(C64) === :C64
    @test constname(D64) === :D64
    @test constname(T64(2)) === Symbol("")
end

@named_consts sizeof(T64) * 2 * 8 T128 A128 B128 C128=sizeof(T128) - B128 D128
@testset "Size 128" begin
    @test sizeof(T128) == 16
    @test A128::T128 == 0
    @test B128::T128 == 1
    @test C128::T128 == 15
    @test D128::T128 == 16
    @test typemin(T128) === A128
    @test typemax(T128) === D128
    @test instances(T128) == (A128, B128, C128, D128)

    @test validate(A128)
    @test validate(B128)
    @test validate(C128)
    @test validate(D128)

    @test validate(T128, 0)
    @test validate(T128, 1)
    @test validate(T128, 15)
    @test validate(T128, 16)

    @test !validate(T128(-1))
    @test !validate(T128(2))
    @test !validate(T128(14))
    @test !validate(T128(17))

    @test constname(A128) === :A128
    @test constname(B128) === :B128
    @test constname(C128) === :C128
    @test constname(D128) === :D128
    @test constname(T128(2)) === Symbol("")
end

@testset "Error" begin
    @test_throws ArgumentError @eval @named_consts(8, T′, A′=2; B′=10)
    @test !isdefined(:T′)
    @test !isdefined(:A′)
    @test !isdefined(:B′)

    @test_throws ArgumentError @eval @named_consts 8 T′
    @test !isdefined(:T′)

    @test_throws ArgumentError @eval @named_consts 8 T′ []
    @test !isdefined(:T′)

    @test_throws ArgumentError @eval @named_consts 8 T′ A′[1]=2
    @test !isdefined(:T′)
    @test !isdefined(:A′)

    @test_throws ArgumentError @eval @named_consts 8 T′ 10
    @test !isdefined(:T′)

    @test_throws ArgumentError @eval @named_consts 8 T′[] A′
    @test !isdefined(:T′)
    @test !isdefined(:A′)
end
