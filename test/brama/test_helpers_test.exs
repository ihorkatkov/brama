defmodule Brama.TestHelpersTest do
  use Brama.TestCase

  alias Brama.TestHelpers

  describe "circuit state manipulation" do
    test "set_state to open" do
      Brama.register("test_api")

      assert :ok = TestHelpers.set_state("test_api", :open)
      assert {:ok, %{state: :open}} = Brama.status("test_api")
    end

    test "set_state to closed" do
      Brama.register("test_api")
      Brama.open_circuit!("test_api")

      assert :ok = TestHelpers.set_state("test_api", :closed)
      assert {:ok, %{state: :closed}} = Brama.status("test_api")
    end

    test "set_state to half-open" do
      Brama.register("test_api")

      assert :ok = TestHelpers.set_state("test_api", :half_open)
      assert {:ok, %{state: :half_open}} = Brama.status("test_api")
    end
  end

  describe "failure simulation" do
    test "add_failures" do
      Brama.register("test_api", max_attempts: 5)
      assert :ok = TestHelpers.add_failures("test_api", 3)
      assert {:ok, %{failure_count: 3}} = Brama.status("test_api")
    end

    test "add_failures opens circuit when threshold reached" do
      Brama.register("test_api", max_attempts: 3)
      assert :ok = TestHelpers.add_failures("test_api", 3)
      assert {:ok, %{state: :open}} = Brama.status("test_api")
    end

    test "simulate_failures" do
      Brama.register("test_api")
      assert :ok = TestHelpers.simulate_failures("test_api", 2)
      assert {:ok, %{failure_count: 2}} = Brama.status("test_api")
    end

    test "simulate_recovery" do
      Brama.register("test_api")
      TestHelpers.add_failures("test_api", 2)
      assert :ok = TestHelpers.simulate_recovery("test_api")
      assert {:ok, %{failure_count: 0}} = Brama.status("test_api")
    end
  end

  describe "assertions" do
    test "assert_circuit_open" do
      Brama.register("test_api")
      Brama.open_circuit!("test_api")
      assert {:ok, %{state: :open}} = Brama.status("test_api")
    end

    test "assert_circuit_closed" do
      Brama.register("test_api")
      assert {:ok, %{state: :closed}} = Brama.status("test_api")
    end

    test "assert_circuit_half_open" do
      Brama.register("test_api")
      TestHelpers.set_state("test_api", :half_open)
      assert {:ok, %{state: :half_open}} = Brama.status("test_api")
    end
  end
end
