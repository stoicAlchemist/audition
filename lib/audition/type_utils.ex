import Bitwise

defmodule Audition.TypeUtils do
  @moduledoc """
  Audition's utility funtions for file operations
  """
  @doc since: "0.0.1"

  @doc """
  Check if file is an mp3 file according to https://en.wikipedia.org/wiki/MP3

  Returns `boolean`

  ## Examples

      iex> Audition.TypeUtils.is_mp3?("./test/files/test.mp3")
      true

  """
  @doc since: "0.0.1"
  def is_mp3?(path) do
    {:ok, raw_content} = File.open(path)
    bin_content = IO.binread(raw_content, :all)

    # ID3v2.4.0
    # MP3 files could have an ID3 tag, check for it
    # <<i::8, d::8, three::8, _rest::binary>> = bin_content
    <<i::8, d::8, three::8, _rest::binary>> = bin_content

    if <<i::8, d::8, three::8>> == "ID3" do
      true
    else
      <<sync_word::12, version::1, layer::2, _error_bitrate_freq_pad_priv::9>> =
        <<i::8, d::8, three::8>>

      # 01 = Layer 3
      <<sync_word>> == <<0xFFF>> &&
        version == 1 &&
        layer == 1
    end
  end

  @doc """
  Remove the ID3 tag from the binary content given.
  ID3 is taken from: https://id3.org/id3v2.4.0-structure

  Return `binary()`

  ## Examples

      iex> {:ok, raw_content} = File.open("./test/files/test.mp3")
      iex> bin_mp3 = IO.binread(raw_content, :all)
      iex> Audition.TypeUtils.remove_id3(bin_mp3)
      <<...>>
  """
  def remove_id3(
        <<
          "ID3",
          _major_version_revision::16,
          unsyncronisation_flag::1,
          extended_header_flag::1,
          experimental_indicator_flag::1,
          footer_present::1,
          _flags_padding::4,
          unsynchsafe_size::binary-size(4),
          rest::binary
        >> = bin_content
      ) do
    # Number of bytes, not bits
    int_decoded_size =
      if unsyncronisation_flag == 1 do
        unsynchsafe_size
        |> decode_unsynchsafe_unsigned()
      else
        :binary.decode_unsigned(unsynchsafe_size)
      end

    if unsyncronisation_flag == 1, do: IO.puts("Unsyncronisation flag is set")

    int_decoded_xhsize =
      if extended_header_flag == 1 do
        # Extended Header: size, number of flag bytes and extended flags
        <<
          synchsafe_xhsize::binary-size(4),
          _number_flag_bytes::16,
          _extended_flags::16,
          _id3xheadless::binary
        >> = rest

        synchsafe_xhsize
        |> decode_unsynchsafe_unsigned()
      else
        0
      end

    if experimental_indicator_flag == 1, do: IO.puts("Experimental Indicator flag is set")

    # Precense of the footer indicate 10 or 20 bits at the end.
    plus_bytes =
      if footer_present == 1 do
        20
      else
        10
      end

    # Tag
    id3tag_size = int_decoded_size + int_decoded_xhsize + plus_bytes

    <<_id3_tag::size(id3tag_size * 8), mp3_content::bitstring>> = bin_content

    mp3_content
  end

  @doc """
  Decode unsynchsafe encoded integer.

  Return `Integer`

  ## Examples

      iex> Audition.TypeUtils.decode_unsynchsafe_unsigned(binary_variable)
      53
  """
  def decode_unsynchsafe_unsigned(<<b>>), do: b

  def decode_unsynchsafe_unsigned(encoded_binary) do
    encoded_binary
    |> :binary.bin_to_list()
    |> Enum.reverse()
    |> Enum.with_index()
    |> Enum.reduce(0, fn {el, index}, acc ->
      acc ||| el <<< (index * 7)
    end)
  end
end
