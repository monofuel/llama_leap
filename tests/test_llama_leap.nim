## llama_leap API tests
## Ensure that ollama is running!

import
  std/[unittest, json, options, strutils],
  llama_leap, jsony

const
  TestModel = "llama3.1:8b"
  TestModelfileName = "test-pirate-llama3.1"

suite "llama_leap":
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

  suite "list":
    test "list model tags":
      let resp = ollama.listModels()
      var resultStr = ""
      for model in resp.models:
        resultStr.add(model.name & " ")
      echo "> " & resultStr.strip()

  suite "generate":

    test "load llama3.1":
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

  suite "chat":
    test "simple /api/chat":
      let messages = @[
        "How are you today?",
        "I'm doing well, how are you?",
        "I'm doing well, thanks for asking.",
      ]
      echo "> " & ollama.chat(TestModel, messages)

    test "typed /api/chat":
      let req = ChatReq(
        model: TestModel,
        messages: @[
          ChatMessage(
            role: "system",
            content: option("Please talk like a pirate. You are Longbeard the llama.")
        ),
        ChatMessage(
          role: "user",
          content: option("How are you today?")
        ),
      ],
        options: option(ModelParameters(
          temperature: option(0.0f),
          seed: option(42)
        ))
      )
      let resp = ollama.chat(req)
      echo "> " & resp.message.content.get.strip()
      
  suite "create":
    test "create specifying modelfile":
      let modelfile = """
FROM llama3.1:8b
PARAMETER temperature 0
PARAMETER num_ctx 4096

SYSTEM Please talk like a pirate. You are Longbeard the llama.
"""
      ollama.createModel(TestModelfileName, modelfile)
    test "use our created modelfile":
      echo "> " & ollama.generate(TestModelfileName, "How are you today?")

  suite "show":
    test "show model":
      let resp = ollama.showModel(TestModelfileName)
      echo "> " & toJson(resp)
      # assert that special keywords are working properly
      assert resp.`template` != ""

  suite "embeddings":
    test "generate embeddings":
      let resp = ollama.generateEmbeddings(TestModel, "How are you today?")
      echo "Embedding Length: " & $resp.embedding.len
