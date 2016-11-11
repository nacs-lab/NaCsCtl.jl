#!/usr/bin/julia

immutable Pulse
    start::Int64
    len::Int64
end

@inline function overlaps(p1::Pulse, p2::Pulse)
    if p1.start == p2.start
        return true
    elseif p1.start < p2.start
        # A pulse only "weakly" owns the end of the time interval so
        # it's fine if the end of `p1` is the start of `p2` as long as
        # the length of `p1` is not `0`.
        return p1.start + p1.len > p2.start
    else
        return p2.start + p2.len > p1.start
    end
end

immutable NaiveCheckPulser
end

new_seq(::NaiveCheckPulser) = Pulse[]
function add_pulse!(::NaiveCheckPulser, pulses, new_pulse::Pulse)
    @inbounds for p in pulses
        if overlaps(p, new_pulse)
            throw(ArgumentError("Pulse $p and $new_pulse overlaps"))
        end
    end
    push!(pulses, new_pulse)
    return pulses
end

immutable NoCheckPulser
end

new_seq(::NoCheckPulser) = Pulse[]
function add_pulse!(::NoCheckPulser, pulses, new_pulse::Pulse)
    push!(pulses, new_pulse)
    return pulses
end

function benchmark_add(pulser, n)
    pulses = new_seq(pulser)
    for i in shuffle(1:n)
        add_pulse!(pulser, pulses, Pulse(i, 1))
    end
    return pulses
end

@time sin(1)

benchmark_add(NaiveCheckPulser(), 1)
@time benchmark_add(NaiveCheckPulser(), 30_000)
benchmark_add(NoCheckPulser(), 1)
@time benchmark_add(NoCheckPulser(), 30_000)
