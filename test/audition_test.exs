defmodule AuditionTest do
  use ExUnit.Case
  doctest Audition

  test "detects mp3 file" do
    audio_file = "test/files/test.mp3"
    raw_audio = "test/files/no_id3.mp3"
    image = "test/files/image.png"

    assert Audition.TypeUtils.is_mp3?(audio_file) == true
    assert Audition.TypeUtils.is_mp3?(raw_audio) == true
    assert Audition.TypeUtils.is_mp3?(image) == false
  end

  test "extracts audio binary from ID3 tagged mp3 binary" do
    audio_file = "test/files/test.mp3"
    {:ok, test_file} = File.open(audio_file)
    raw_test = IO.binread(test_file, :all)

    raw_audio_path = "test/files/no_id3.mp3"
    {:ok, file} = File.open(raw_audio_path)
    raw_audio = IO.binread(file, :all)

    assert Audition.TypeUtils.remove_id3(raw_test) == raw_audio
  end
end
