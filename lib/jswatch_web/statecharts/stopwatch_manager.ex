defmodule JswatchWeb.StopwatchManager do
  use GenServer

  def init(ui_pid) do
    :gproc.reg({:p, :l, :ui_event})
    {:ok, %{ui_pid: ui_pid, mode: :clock, running: false, elapsed: 0, timer: nil}}
  end

  # 1) Toggle modo
  def handle_info(:"top-left-pressed", %{ui_pid: pid, mode: :clock, elapsed: e} = state) do
    GenServer.cast(pid, {:set_stopwatch_display, format_elapsed(e)})
    {:noreply, %{state | mode: :stopwatch}}
  end
  def handle_info(:"top-left-pressed", %{mode: :stopwatch} = state) do
    {:noreply, %{state | mode: :clock}}
  end

  # 2) Arrancar / pausar
  def handle_info(:"bottom-right-pressed", %{ui_pid: pid, mode: :stopwatch, running: false} = state) do
    GenServer.cast(pid, {:set_stopwatch_display, format_elapsed(state.elapsed)})
    timer = Process.send_after(self(), :tick, 10)
    {:noreply, %{state | running: true, timer: timer}}
  end
  def handle_info(:"bottom-right-pressed", %{mode: :stopwatch, running: true, timer: timer} = state) do
    if timer, do: Process.cancel_timer(timer)
    {:noreply, %{state | running: false, timer: nil}}
  end

  # 3) Tick
  def handle_info(:tick, %{ui_pid: pid, running: true, elapsed: e} = state) do
    new_elapsed = e + 10
    GenServer.cast(pid, {:set_stopwatch_display, format_elapsed(new_elapsed)})
    timer = Process.send_after(self(), :tick, 10)
    {:noreply, %{state | elapsed: new_elapsed, timer: timer}}
  end
  def handle_info(:tick, state), do: {:noreply, state}

  # 4) Reset
  def handle_info(:"bottom-left-released", %{ui_pid: pid, mode: :stopwatch, running: false} = state) do
    GenServer.cast(pid, {:set_stopwatch_display, format_elapsed(0)})
    {:noreply, %{state | elapsed: 0}}
  end

  # Catch-all
  def handle_info(_event, state), do: {:noreply, state}

  defp format_elapsed(ms) do
    minutes = div(ms, 60_000)
    seconds = div(rem(ms, 60_000), 1_000)
    cents   = div(rem(ms, 1_000), 10)
    :io_lib.format("~2..0B:~2..0B:~2..0B", [minutes, seconds, cents])
    |> to_string()
  end
end
