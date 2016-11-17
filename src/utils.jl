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
