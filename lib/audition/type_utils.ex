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
          _footer_present::1,
          _flags_padding::4,
          unsynchsafe_size::binary-size(4),
          rest::binary
        >> = bin_content
      ) do
    # Number of bytes, not bits
    int_decoded_size =
      unsynchsafe_size
      |> :binary.decode_unsigned()
      |> decode_synchsafe_unsigned()

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
        |> decode_synchsafe_unsigned()
      else
        0
      end

    if experimental_indicator_flag == 1, do: IO.puts("Experimental Indicator flag is set")

    # Tag, 10bytes for ID3 header
    id3tag_size = int_decoded_size + int_decoded_xhsize + 10

    <<_id3_tag::size(id3tag_size * 8), mp3_content::bitstring>> = bin_content

    mp3_content
  end

  # If the binary doesn't have a tag, just return it
  def remove_id3(<<255, _rest::binary>> = audio), do: audio

  @doc """
  Encode an integer to a synchsafe encoded integer. A basic example would be the number 255, the binary
  representation is <<0b11111111>>. Encoding it to synchsafe would mean that only 7 bits are
  usable, the 8th should always be a zero so the encoded binary would be
  <<0b00000001, 0b01111111>> which  is the correct representation of the number 383.

  Return `Binary`

  ## Examples

    iex> Audition.TypeUtils.encode_unsynchsafe_unsigned(255)
    383
  """
  @spec encode_unsynchsafe_unsigned(integer()) :: integer()
  def encode_unsynchsafe_unsigned(int32) when is_integer(int32) do
    int32
    |> :binary.encode_unsigned()
    |> :binary.bin_to_list()
    |> Enum.reverse()
    |> Enum.with_index()
    |> Enum.reduce(0, fn {el, index}, acc ->
      el <<< (index * 8 + index + 1)
      |> :binary.encode_unsigned()
      |> :binary.bin_to_list()
      |> Enum.with_index()
      |> unshift_needed(index + 1)
      |> :binary.list_to_bin()
      |> :binary.decode_unsigned()
      |> Bitwise.|||(acc)
    end)
  end

  @doc """
  Decode a synchsafe encoded integer.

  ## Examples

    iex> Audition.TypeUtils.decode_synchsafe_unsigned(383)
    255
  """
  @spec decode_synchsafe_unsigned(integer()) :: integer()
  def decode_synchsafe_unsigned(synchsafe_int32) when is_integer(synchsafe_int32) do
    synchsafe_int32
    |> :binary.encode_unsigned()
    |> :binary.bin_to_list()
    |> Enum.reverse()
    |> Enum.with_index()
    |> Enum.reduce(0, fn {el, idx}, acc ->
      acc ||| (el <<< (7 * idx))
    end)
  end

  @spec unshift_needed(list(tuple()), integer()) :: list(integer())
  defp unshift_needed(list_num, old_size) do
    # When a new byte was added result of the left bit shifting
    # you don't need to unshift that

    if length(list_num) > old_size do
      list_num
      |> Enum.map(fn
        {new_shifted, 0} -> new_shifted
        {to_shift, _} -> to_shift >>> 1
      end)
    else
      list_num
      |> Enum.map(fn
        {to_shift, _} -> to_shift >>> 1
      end)
    end
  end
end
