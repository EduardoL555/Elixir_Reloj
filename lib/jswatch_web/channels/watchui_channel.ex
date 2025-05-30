defmodule JswatchWeb.WatchUIChannel do
  use Phoenix.Channel

  def join("watch:ui", _message, socket) do
    # Arrancamos los 3 GenServers
    GenServer.start_link(JswatchWeb.ClockManager,    self())
    GenServer.start_link(JswatchWeb.IndigloManager,  self())
    GenServer.start_link(JswatchWeb.StopwatchManager,self())
    # Guardamos el modo actual en assigns
    socket = assign(socket, :mode, :clock)
    {:ok, socket}
  end

  # Interceptamos top-left para toggle de modo
  def handle_in("top-left-pressed", _payload, socket) do
    # Ahora enviamos el átomo con guión, para que coincida con
    # los handle_info(:"top-left-pressed", …) de los managers:
    :gproc.send({:p, :l, :ui_event}, String.to_atom("top-left-pressed"))
    # Alternamos el modo en el socket
    new_mode = case socket.assigns.mode do
      :clock     -> :stopwatch
      :stopwatch -> :clock
    end
    {:noreply, assign(socket, :mode, new_mode)}
  end

  # Resto de eventos van directo
  def handle_in(event, _payload, socket) do
    :gproc.send({:p, :l, :ui_event}, String.to_atom(event))
    {:noreply, socket}
  end

  # Sólo empujamos el display de hora si estamos en modo reloj
  def handle_cast({:set_time_display, str}, %{assigns: %{mode: :clock}} = socket) do
    push(socket, "setTimeDisplay", %{time: str})
    {:noreply, socket}
  end
  def handle_cast({:set_time_display, _}, socket), do: {:noreply, socket}

  # Sólo empujamos el display de cronómetro si estamos en modo stopwatch
  def handle_cast({:set_stopwatch_display, str}, %{assigns: %{mode: :stopwatch}} = socket) do
    push(socket, "setTimeDisplay", %{time: str})
    {:noreply, socket}
  end
  def handle_cast({:set_stopwatch_display, _}, socket), do: {:noreply, socket}

  # Indiglo y alarma quedan igual
  def handle_cast(:set_indiglo, socket) do
    push(socket, "setIndiglo", %{})
    {:noreply, socket}
  end
  def handle_cast(:unset_indiglo, socket) do
    push(socket, "unsetIndiglo", %{})
    {:noreply, socket}
  end
end
