defmodule UwUBlog.PostPending do
  @moduledoc """
  This module contains posts that are pending to be processed.
  """

  defstruct [
    :entry,
    :dir
  ]

  @type t :: %__MODULE__{
          entry: String.t(),
          dir: String.t()
        }
end
