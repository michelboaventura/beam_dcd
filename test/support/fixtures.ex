# Test fixture modules — compiled as part of the test suite so their .beam
# files are available for analysis. Each module tests a specific scenario.

defmodule TestFixtures.UsedFunctions do
  @moduledoc false
  def public_used, do: :ok
  def public_unused, do: :never_called

  def caller do
    public_used()
  end
end

defmodule TestFixtures.CrossModuleCaller do
  @moduledoc false
  def call_other_module do
    TestFixtures.UsedFunctions.public_used()
  end
end

defmodule TestFixtures.GenServerImpl do
  @moduledoc false
  use GenServer

  # Behaviour callbacks — should NOT be reported as unused
  @impl true
  def init(_), do: {:ok, %{}}

  @impl true
  def handle_call(_msg, _from, state), do: {:reply, :ok, state}

  @impl true
  def handle_cast(_msg, state), do: {:noreply, state}

  # Should be reported as unused
  def unused_public, do: :not_called
end

defmodule TestFixtures.FunCapture do
  @moduledoc false
  def captured_function(x), do: x * 2
  def unused_function, do: :unused

  def use_capture do
    Enum.map([1, 2, 3], &captured_function/1)
  end
end

defmodule TestFixtures.DynamicCalls do
  @moduledoc false
  def dynamic_target, do: :ok
  def static_target, do: :ok

  def call_dynamically(mod, fun) do
    apply(mod, fun, [])
  end

  def call_statically do
    static_target()
  end
end

defmodule TestFixtures.NoExternalCallers do
  @moduledoc false
  # This module has no external callers at all
  def orphan_a, do: :a
  def orphan_b, do: :b
  def orphan_c, do: :c
end

defmodule TestFixtures.StructModule do
  @moduledoc false
  defstruct [:name, :value]

  # __struct__/0 and __struct__/1 should not be reported
  def unused_helper, do: :unused
end
