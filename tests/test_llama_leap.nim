## llama_leap API tests
## Ensure that ollama is running!

import llama_leap, unittest


suite "llama_leap":
  var ollama: OllamaAPI

  setup:
    ollama = newOllamaApi()
  teardown:
    ollama.close()

  test "TODO":
    echo "TODO"
