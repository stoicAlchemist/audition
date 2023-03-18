defmodule AuditionTest do
  use ExUnit.Case
  doctest Audition

  test "detects mp3 file" do
    audio_file = "test/files/with_id3.mp3"
    raw_audio = "test/files/no_id3.mp3"
    image = "test/files/image.png"

    assert Audition.TypeUtils.is_mp3?(audio_file) == true
    assert Audition.TypeUtils.is_mp3?(raw_audio) == true
    assert Audition.TypeUtils.is_mp3?(image) == false
  end

  test "extracts audio binary from ID3 tagged mp3 binary" do
    {:ok, test_file} =
      "test/files/with_id3.mp3"
      |> File.open()

    raw_test = IO.binread(test_file, :all)

    {:ok, audio_file} =
      "test/files/no_id3.mp3"
      |> File.open()

    raw_audio = IO.binread(audio_file, :all)

    {:ok, full_audio} =
      "test/files/full_id3.mp3"
      |> File.open()

    bin_full = IO.binread(full_audio, :all)

    assert Audition.TypeUtils.remove_id3(raw_test) == raw_audio
    assert Audition.TypeUtils.remove_id3(raw_audio) == raw_audio
    assert Audition.TypeUtils.remove_id3(bin_full) == raw_audio
  end

  test "encodes syncsafe integer" do
    d32bit = <<0b00001111, 0b11111111, 0b11111111, 0b11111111>> |> :binary.decode_unsigned()
    e32bit = <<0b01111111, 0b01111111, 0b01111111, 0b01111111>> |> :binary.decode_unsigned()

    d255 = <<0b00000000, 0b00000000, 0b00000000, 0b11111111>> |> :binary.decode_unsigned()
    e255 = <<0b00000000, 0b00000000, 0b00000001, 0b01111111>> |> :binary.decode_unsigned()

    d32bit_l0 = <<0b11111111, 0b01111111>> |> :binary.decode_unsigned()
    e32bit_l0 = <<0b00000011, 0b01111110, 0b01111111>> |> :binary.decode_unsigned()

    d32bit_m0 = <<0b00001110, 0b01111111>> |> :binary.decode_unsigned()
    e32bit_m0 = <<0b00011100, 0b01111111>> |> :binary.decode_unsigned()

    d32bitsmall = <<0b00001010>> |> :binary.decode_unsigned()

    assert Audition.TypeUtils.encode_unsynchsafe_unsigned(d32bit) == e32bit
    assert Audition.TypeUtils.encode_unsynchsafe_unsigned(d255) == e255
    assert Audition.TypeUtils.encode_unsynchsafe_unsigned(d32bitsmall) == d32bitsmall
    assert Audition.TypeUtils.encode_unsynchsafe_unsigned(d32bit_l0) == e32bit_l0
    assert Audition.TypeUtils.encode_unsynchsafe_unsigned(d32bit_m0) == e32bit_m0
  end

  test "decodes synchsafe encoded integer" do
    d32bit = <<0b00001111, 0b11111111, 0b11111111, 0b11111111>> |> :binary.decode_unsigned()
    e32bit = <<0b01111111, 0b01111111, 0b01111111, 0b01111111>> |> :binary.decode_unsigned()

    d255 = <<0b00000000, 0b00000000, 0b00000000, 0b11111111>> |> :binary.decode_unsigned()
    e255 = <<0b00000000, 0b00000000, 0b00000001, 0b01111111>> |> :binary.decode_unsigned()

    d32bit_l0 = <<0b11111111, 0b01111111>> |> :binary.decode_unsigned()
    e32bit_l0 = <<0b00000011, 0b01111110, 0b01111111>> |> :binary.decode_unsigned()

    d32bit_m0 = <<0b00001110, 0b01111111>> |> :binary.decode_unsigned()
    e32bit_m0 = <<0b00011100, 0b01111111>> |> :binary.decode_unsigned()

    d32bitsmall = <<0b00001010>> |> :binary.decode_unsigned()

    assert Audition.TypeUtils.decode_synchsafe_unsigned(e32bit) == d32bit
    assert Audition.TypeUtils.decode_synchsafe_unsigned(e255) == d255
    assert Audition.TypeUtils.decode_synchsafe_unsigned(d32bitsmall) == d32bitsmall
    assert Audition.TypeUtils.decode_synchsafe_unsigned(e32bit_l0) == d32bit_l0
    assert Audition.TypeUtils.decode_synchsafe_unsigned(e32bit_m0) == d32bit_m0
  end
end
