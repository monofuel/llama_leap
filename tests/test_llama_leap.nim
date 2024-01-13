## llama_leap API tests
## Ensure that ollama is running!

import llama_leap, std/[unittest, json, options, strutils]

const TestModel = "llama2"

suite "llama_leap":
  var ollama: OllamaAPI

  setup:
    ollama = newOllamaAPI()
  teardown:
    ollama.close()

  suite "pull":
    test "pull model":
      ollama.pullModel(TestModel)

  suite "list":
    test "list model tags":
      let resp = ollama.listModels()
      var resultStr = ""
      for model in resp.models:
        resultStr.add(model.name & " ")
      echo "> " & resultStr.strip()

  suite "generate":

    test "load llama2":
      ollama.loadModel(TestModel)

    test "simple /api/generate":
      echo "> " & ollama.generate(TestModel, "How are you today?")

    test "typed /api/generate":
      let req = GenerateReq(
        model: TestModel,
        prompt: "How are you today?",
        options: option(ModelParameters(
          temperature: option(0.0f),
          seed: option(42)
        )),
        system: option("Please talk like a pirate. You are Longbeard the llama.")
      )
      let resp = ollama.generate(req)
      echo "> " & resp.response.strip()

    test "json /api/generate":
      let req = %*{
        "model": TestModel,
        "prompt": "How are you today?",
        "system": "Please talk like a ninja. You are Sneaky the llama.",
        "options": {
          "temperature": 0.0
        }
      }
      let resp = ollama.generate(req)
      echo "> " & resp["response"].getStr.strip()

    test "context":
      let req = GenerateReq(
        model: TestModel,
        prompt: "How are you today?",
        system: option("Please talk like a pirate. You are Longbeard the llama."),
        options: option(ModelParameters(
          temperature: option(0.0f),
          seed: option(42)
        )),
      )
      let resp = ollama.generate(req)
      echo "1> " & resp.response.strip()

      let req2 = GenerateReq(
        model: TestModel,
        prompt: "How are you today?",
        context: option(resp.context),
        options: option(ModelParameters(
          temperature: option(0.0f),
          seed: option(42)
        )),
      )
      let resp2 = ollama.generate(req2)
      echo "2> " & resp2.response.strip()

  suite "embeddings":
    test "generate embeddings":
      let resp = ollama.generateEmbeddings(TestModel, "How are you today?")
      echo "Embedding Length: " & $resp.embedding.len
