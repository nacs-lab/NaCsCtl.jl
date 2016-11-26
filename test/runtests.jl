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

import NaCsCtl
using Base.Test

@testset "Channel" begin
    root = NaCsCtl.Channels.Node()
    @test sprint(show, root) == "Node(children=[])"
    @test NaCsCtl.Channels.is_root(root)
    ch1 = root["a"]
    @test sprint(show, root) == "Node(children=[\"a\"])"
    @test sprint(show, ch1) == "Node(name=\"a\", parent=root, children=[])"
    @test root["a"] === ch1
    @test ch1.name == "a"
    @test NaCsCtl.Channels.get_path(ch1) == ["a"]

    root[["a", "b"]] = ["c", "d", "e"]
    @test root[["a", "b"]] === root[["c", "d", "e"]]
    @test sprint(show, root["a"]) == "Node(name=\"a\", parent=root, children=[\"b\" -> [\"c\", \"d\", \"e\"]])"
end

@testset "IR" begin
    include("ir.jl")
end

@testset "Utils" begin
    include("utils.jl")
end
