defmodule UwUBlog.PasskeysTest do
  use UwUBlog.DataCase, async: true

  alias UwUBlog.Passkeys
  alias UwUBlog.Passkeys.Credential

  @cose %{-3 => "x", -2 => "y", -1 => 1, 1 => 2, 3 => -7}

  defp attrs(overrides \\ %{}) do
    Enum.into(overrides, %{
      credential_id: "credential-1",
      public_key: :erlang.term_to_binary(@cose),
      sign_count: 0,
      label: "YubiKey"
    })
  end

  test "create_credential/1 stores a credential and any?/0 reflects it" do
    refute Passkeys.any?()
    assert {:ok, %Credential{}} = Passkeys.create_credential(attrs())
    assert Passkeys.any?()
  end

  test "create_credential/1 requires a label" do
    assert {:error, changeset} = Passkeys.create_credential(attrs(%{label: ""}))
    assert %{label: _} = errors_on(changeset)
  end

  test "credential_id is unique" do
    assert {:ok, _} = Passkeys.create_credential(attrs())
    assert {:error, changeset} = Passkeys.create_credential(attrs())
    assert %{credential_id: _} = errors_on(changeset)
  end

  test "get_by_credential_id/1 finds the stored credential" do
    {:ok, credential} = Passkeys.create_credential(attrs())
    assert Passkeys.get_by_credential_id("credential-1").id == credential.id
    refute Passkeys.get_by_credential_id("nope")
  end

  test "the COSE public key round-trips through storage" do
    {:ok, credential} = Passkeys.create_credential(attrs())
    assert :erlang.binary_to_term(credential.public_key) == @cose
  end

  test "update_sign_count/2 bumps the counter" do
    {:ok, credential} = Passkeys.create_credential(attrs())
    assert {:ok, updated} = Passkeys.update_sign_count(credential, 7)
    assert updated.sign_count == 7
  end

  test "delete_credential/1 removes it" do
    {:ok, credential} = Passkeys.create_credential(attrs())
    assert {:ok, _} = Passkeys.delete_credential(credential)
    refute Passkeys.any?()
  end
end
