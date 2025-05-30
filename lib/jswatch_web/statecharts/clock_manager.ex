defmodule JswatchWeb.ClockManager do
  use GenServer


  @working_tick_interval 1_000
  @blink_interval         250
  @edit_max_count         20


  # Inicialización
  def init(ui_pid) do
    :gproc.reg({:p, :l, :ui_event})
    {_, now} = :calendar.local_time()
    time    = Time.from_erl!(now)
    alarm   = Time.add(time, 10)
    timer = Process.send_after(self(), :working_working, @working_tick_interval)


    {:ok,
     %{
       ui_pid:    ui_pid,
       time:      time,
       alarm:     alarm,
       st:        :working,
       timer:     timer,
       selection: nil,
       show:      false,
       count:     0
     }}
  end


  # Actualización manual de la alarma
  def handle_info(:update_alarm, state) do
    {_, now} = :calendar.local_time()
    time      = Time.from_erl!(now)
    alarm     = Time.add(time, 5)
    {:noreply, %{state | alarm: alarm}}
  end


  # Tick del reloj cada segundo en modo :working-
  def handle_info(:working_working,
      %{ui_pid: ui, time: t, alarm: alarm, st: :working, timer: old_timer} = state) do
    Process.cancel_timer(old_timer)
    new_timer = Process.send_after(self(), :working_working, @working_tick_interval)
    new_time  = Time.add(t, 1)


    if new_time == alarm do
      IO.puts("ALARM!!!")
      :gproc.send({:p, :l, :ui_event}, :start_alarm)
    end


    GenServer.cast(ui, {:set_time_display, Time.truncate(new_time, :second) |> Time.to_string()})
    {:noreply, %{state | time: new_time, timer: new_timer}}
  end


  # Primer click bottom-right en :working → :pending_edit
  def handle_info(:"bottom-right-pressed", %{st: :working, timer: t} = state) do
    Process.cancel_timer(t)
    {:noreply, %{state | st: :pending_edit}}
  end


  # Segundo click bottom-right en :pending_edit → :editing
  def handle_info(:"bottom-right-pressed",
      %{st: :pending_edit, ui_pid: ui, time: t0} = state) do
    display     = format(t0, :hour, true)
    blink_timer = Process.send_after(self(), :editing_blink, @blink_interval)
    GenServer.cast(ui, {:set_time_display, display})


    {:noreply,
     %{state |
       st:        :editing,
       selection: :hour,
       show:      true,
       count:     0,
       timer:     blink_timer
     }}
  end


  # Parpadeo en modo :editing con timeout
  def handle_info(:editing_blink,
      %{st: :editing, ui_pid: ui, time: t_cur, selection: sel, show: sh, count: cnt, timer: old_timer} = state) do
    Process.cancel_timer(old_timer)
    next_count = cnt + 1


    if next_count < @edit_max_count do
      new_show    = not sh
      display     = format(t_cur, sel, new_show)
      GenServer.cast(ui, {:set_time_display, display})


      blink_timer = Process.send_after(self(), :editing_blink, @blink_interval)
      {:noreply,
       %{state |
         show:  new_show,
         count: next_count,
         timer: blink_timer
       }}
    else
      full_display = Time.truncate(t_cur, :second) |> Time.to_string()
      GenServer.cast(ui, {:set_time_display, full_display})


      timer = Process.send_after(self(), :working_working, @working_tick_interval)
      {:noreply,
       %{state |
         st:        :working,
         timer:     timer,
         selection: nil,
         show:      false,
         count:     0
       }}
    end
  end


  # Cambio de selección en modo :editing
  def handle_info(:"bottom-right-pressed",
      %{st: :editing, ui_pid: ui, time: t0, selection: sel, timer: old_timer} = state) do
    Process.cancel_timer(old_timer)
    new_sel = case sel do
      :hour   -> :minute
      :minute -> :second
      :second -> :hour
    end
    display     = format(t0, new_sel, true)
    blink_timer = Process.send_after(self(), :editing_blink, @blink_interval)
    GenServer.cast(ui, {:set_time_display, display})


    {:noreply,
     %{state |
       selection: new_sel,
       show:      true,
       count:     0,
       timer:     blink_timer
     }}
  end


  # Incremento en modo :editing
  def handle_info(:"bottom-left-pressed",
      %{st: :editing, ui_pid: ui, time: t_cur, selection: sel, timer: old_timer} = state) do
    Process.cancel_timer(old_timer)
    new_time    = increase_selection(t_cur, sel)
    display     = format(new_time, sel, true)
    blink_timer = Process.send_after(self(), :editing_blink, @blink_interval)
    GenServer.cast(ui, {:set_time_display, display})


    {:noreply,
     %{state |
       time:      new_time,
       show:      true,
       count:     0,
       timer:     blink_timer
     }}
  end


  # Catch-all para otros eventos
  def handle_info(_event, state), do: {:noreply, state}


  # Helpers para formatear y modificar HH:MM:SS
  defp format(%Time{hour: h, minute: m, second: s}, sel, show) do
    hh = if sel == :hour   and not show, do: "  ", else: pad(h)
    mm = if sel == :minute and not show, do: "  ", else: pad(m)
    ss = if sel == :second and not show, do: "  ", else: pad(s)
    "#{hh}:#{mm}:#{ss}"
  end


  defp pad(n) when n < 10, do: "0#{n}"
  defp pad(n), do: "#{n}"


  defp increase_selection(%Time{hour: h} = t, :hour),   do: %Time{t | hour: rem(h + 1, 24)}
  defp increase_selection(%Time{minute: m} = t, :minute), do: %Time{t | minute: rem(m + 1, 60)}
  defp increase_selection(%Time{second: s} = t, :second), do: %Time{t | second: rem(s + 1, 60)}
end
