## llama_leap API tests
## Ensure that ollama is running!

import llama_leap, std/[unittest, json, options]

suite "llama_leap":
  var ollama: OllamaAPI

  setup:
    ollama = newOllamaAPI()
  teardown:
    ollama.close()

  suite "generate":
    test "simple /api/generate":
      echo "> " & ollama.generate("llama2", "How are you today?")

    test "typed /api/generate":
      let req = GenerateReq(
        model: "llama2",
        prompt: "How are you today?",
        system: option("Please talk like a pirate. You are Longbeard the llama.")
      )
      let resp = ollama.generate(req)
      echo "> " & resp.response
    test "json /api/generate":
      let req = %*{
        "model": "llama2",
        "prompt": "How are you today?",
        "system": "Please talk like a ninja. You are Sneaky the llama."
      }
      let resp = ollama.generate(req)
      echo "> " & resp["response"].getStr
