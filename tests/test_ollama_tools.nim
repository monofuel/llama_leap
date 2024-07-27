## ollama tools test
## Ensure that ollama is running!

import
  std/[unittest],
  llama_leap

# Must use a tools compatible model!
const
  TestModel = "llama3.1:8b"

suite "ollama tools":
  var ollama: OllamaAPI

  setup:
    ollama = newOllamaAPI()
  teardown:
    ollama.close()

  suite "version":
    test "version":
      echo "> " & ollama.getVersion()
  suite "pull":
    test "pull model":
      ollama.pullModel(TestModel)

  # TODO do the thing