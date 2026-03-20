defmodule BeamDcd.EntrypointDetectorTest do
  use ExUnit.Case, async: true

  alias BeamDcd.EntrypointDetector

  describe "compiler_generated?/1" do
    test "detects module_info/0 and module_info/1" do
      assert EntrypointDetector.compiler_generated?({SomeModule, :module_info, 0})
      assert EntrypointDetector.compiler_generated?({SomeModule, :module_info, 1})
    end

    test "detects __info__/1" do
      assert EntrypointDetector.compiler_generated?({SomeModule, :__info__, 1})
    end

    test "detects __struct__/0 and __struct__/1" do
      assert EntrypointDetector.compiler_generated?({SomeModule, :__struct__, 0})
      assert EntrypointDetector.compiler_generated?({SomeModule, :__struct__, 1})
    end

    test "detects __impl__/1" do
      assert EntrypointDetector.compiler_generated?({SomeModule, :__impl__, 1})
    end

    test "detects MACRO- prefixed functions" do
      assert EntrypointDetector.compiler_generated?({SomeModule, :"MACRO-my_macro", 2})
    end

    test "does not flag regular functions" do
      refute EntrypointDetector.compiler_generated?({SomeModule, :my_function, 1})
      refute EntrypointDetector.compiler_generated?({SomeModule, :start, 2})
    end
  end

  describe "detect_behaviours/1" do
    test "extracts behaviour declarations from attributes" do
      attributes = [behaviour: [GenServer], vsn: [123]]
      assert EntrypointDetector.detect_behaviours(attributes) == [GenServer]
    end

    test "handles multiple behaviours" do
      attributes = [behaviour: [GenServer], behaviour: [Supervisor]]
      behaviours = EntrypointDetector.detect_behaviours(attributes)
      assert GenServer in behaviours
      assert Supervisor in behaviours
    end

    test "handles empty attributes" do
      assert EntrypointDetector.detect_behaviours([]) == []
    end
  end

  describe "get_behaviour_callbacks/1" do
    test "returns GenServer callbacks" do
      callbacks = EntrypointDetector.get_behaviour_callbacks([GenServer])
      assert {:init, 1} in callbacks
      assert {:handle_call, 3} in callbacks
      assert {:handle_cast, 2} in callbacks
      assert {:handle_info, 2} in callbacks
    end

    test "returns OTP gen_server callbacks" do
      callbacks = EntrypointDetector.get_behaviour_callbacks([:gen_server])
      assert {:init, 1} in callbacks
      assert {:handle_call, 3} in callbacks
    end

    test "returns Supervisor callbacks" do
      callbacks = EntrypointDetector.get_behaviour_callbacks([Supervisor])
      assert {:init, 1} in callbacks
    end

    test "returns empty for unknown behaviours" do
      callbacks = EntrypointDetector.get_behaviour_callbacks([NonExistentBehaviour])
      assert callbacks == []
    end
  end

  describe "filter_entrypoints/3" do
    test "removes compiler-generated functions" do
      exports = [
        {MyModule, :my_function, 1},
        {MyModule, :module_info, 0},
        {MyModule, :module_info, 1},
        {MyModule, :__info__, 1}
      ]

      result = EntrypointDetector.filter_entrypoints(exports, [])
      assert result == [{MyModule, :my_function, 1}]
    end

    test "removes behaviour callbacks" do
      exports = [
        {MyModule, :init, 1},
        {MyModule, :handle_call, 3},
        {MyModule, :my_function, 1},
        {MyModule, :module_info, 0}
      ]

      attributes = [behaviour: [GenServer]]
      result = EntrypointDetector.filter_entrypoints(exports, attributes)
      assert result == [{MyModule, :my_function, 1}]
    end

    test "removes extra entrypoints" do
      exports = [
        {MyModule, :my_function, 1},
        {MyModule, :special_handler, 2},
        {MyModule, :module_info, 0}
      ]

      extra = [{MyModule, :special_handler, 2}]
      result = EntrypointDetector.filter_entrypoints(exports, [], extra)
      assert result == [{MyModule, :my_function, 1}]
    end
  end

  describe "entrypoint?/3" do
    test "returns true for compiler-generated" do
      assert EntrypointDetector.entrypoint?({M, :module_info, 0}, [], [])
    end

    test "returns true for behaviour callbacks" do
      attrs = [behaviour: [GenServer]]
      assert EntrypointDetector.entrypoint?({M, :init, 1}, attrs, [])
    end

    test "returns true for extra entrypoints" do
      extra = [{M, :custom, 2}]
      assert EntrypointDetector.entrypoint?({M, :custom, 2}, [], extra)
    end

    test "returns false for regular functions" do
      refute EntrypointDetector.entrypoint?({M, :regular, 1}, [], [])
    end
  end
end
