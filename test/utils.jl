#

import NaCsCtl: @named_consts

@named_consts 8 T8 A8 B8 C8=B8 + 3 D8
@test sizeof(T8) == 1
@test A8::T8 == 0
@test B8::T8 == 1
@test C8::T8 == 4
@test D8::T8 == 5

@named_consts(16, T16, A16, B16, C16=B16 - 10 + sizeof(T16), D16)
@test sizeof(T16) == 2
@test A16::T16 == 0
@test B16::T16 == 1
@test C16::T16 == -7
@test D16::T16 == -6

t32_size = 4

@named_consts t32_size * 8 T32 A32 B32 C32=Int(B32) + sizeof(T32) D32
@test sizeof(T32) == 4
@test A32::T32 == 0
@test B32::T32 == 1
@test C32::T32 == 5
@test D32::T32 == 6

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
