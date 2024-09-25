import curly, jsony, std/[strutils, tables, json, options, strformat, os]

## ollama API Interface for nim.
## 
## https://github.com/monofuel/llama_leap/blob/main/README.md

# ollama API references
# https://github.com/jmorganca/ollama/blob/main/docs/api.md
# https://github.com/jmorganca/ollama/blob/main/api/types.go

# model parameters: https://github.com/jmorganca/ollama/blob/main/docs/modelfile.md#valid-parameters-and-values

type
  OllamaAPI* = ref object
    curlPool: CurlPool
    baseUrl: string
    curlTimeout: float32

  ModelParameters* = ref object
    mirostat*: Option[int]
    mirostat_eta*: Option[float32]
    mirostat_tau*: Option[float32]
    num_ctx*: Option[int]
    num_gqa*: Option[int]
    num_gpu*: Option[int]
    num_thread*: Option[int]
    repeat_last_n*: Option[int]
    repeat_penalty*: Option[float32]
    temperature*: Option[float32]
    seed*: Option[int]
    stop*: Option[string]
    tfs_z*: Option[float32]
    num_predict*: Option[int]
    top_k*: Option[int]
    top_p*: Option[float32]


  ToolFunctionParameters* = object
    `type`*: string # object
    # had serialization issues when properties was a table
    # it was also kind of confusing to work with
    #properties*: Table[string, ToolFunctionParameter]
    properties*: JsonNode
    required*: seq[string]

  ToolFunction* = ref object
    name*: string
    description*: string
    parameters*: ToolFunctionParameters

  Tool* = ref object
    `type`*: string
    function*: ToolFunction

  GenerateReq* = ref object
    model*: string
    prompt*: string
    images*: Option[seq[string]]      # list of base64 encoded images
    format*: Option[string]           # optional format=json for a structured response
    options*: Option[ModelParameters] # bag of model parameters
    system*: Option[string]           # override modelfile system prompt
    `template`*: Option[string]     # override modelfile template
    context*: Option[seq[int]]        # conversation encoding from a previous response
    stream: Option[bool]              # stream=false to get a single response
    raw*: Option[bool] # use raw=true if you are specifying a fully templated prompt

  GenerateResp* = ref object
    model*: string
    created_at*: string
    response*: string
    done*: bool # always true for stream=false
    context*: seq[int]
    total_duration*: int
    load_duration*: int
    prompt_eval_count*: int
    prompt_eval_duration*: int
    eval_count*: int
    eval_duration*: int

  ToolCallFunction* = ref object
    name*: string
    arguments*: JsonNode # map of [string]: any

  ToolCall* = ref object
    function*: ToolCallFunction

  ChatMessage* = ref object
    role*: string                # "system" "user" "tool" or "assistant"
    content*: Option[string]
    images*: Option[seq[string]] # list of base64 encoded images
    tool_calls*: seq[ToolCall]

  ChatReq* = ref object
    model*: string
    tools*: seq[Tool] # requires stream=false currently
    messages*: seq[ChatMessage]
    format*: Option[string]           # optional format=json for a structured response
    options*: Option[ModelParameters] # bag of model parameters
    `template`*: Option[string]     # override modelfile template
    stream: Option[bool]              # stream=false to get a single response

  ChatResp* = ref object
    model*: string
    created_at*: string
    message*: ChatMessage
    done*: bool # always true for stream=false
    total_duration*: int
    load_duration*: int
    prompt_eval_count*: int
    prompt_eval_duration*: int
    eval_count*: int
    eval_duration*: int

  CreateModelReq* = ref object
    name*: string
    modelfile*: Option[string]
    stream*: bool
    path*: Option[string]

  ModelDetails* = ref object
    format*: string
    family*: string
    families*: Option[seq[string]]
    parameter_size*: string
    quantization_level*: string

  OllamaModel* = ref object
    name*: string
    modified_at*: string
    size*: int
    digest*: string
    details*: ModelDetails

  ListResp* = ref object
    models*: seq[OllamaModel]

  ShowModel* = ref object
    modelfile*: string
    parameters*: string
    `template`*: string
    details*: ModelDetails

  EmbeddingReq* = ref object
    model*: string
    prompt*: string
    options*: Option[ModelParameters] # bag of model parameters

  EmbeddingResp* = ref object
    embedding*: seq[float64]

proc dumpHook(s: var string, v: object) =
  ## jsony `hack` to skip optional fields that are nil
  s.add '{'
  var i = 0
  # Normal objects.
  for k, e in v.fieldPairs:
    when compiles(e.isSome):
      if e.isSome:
        if i > 0:
          s.add ','
        s.dumpHook(k)
        s.add ':'
        s.dumpHook(e)
        inc i
    else:
      if i > 0:
        s.add ','
      s.dumpHook(k)
      s.add ':'
      s.dumpHook(e)
      inc i
  s.add '}'

proc newOllamaAPI*(
    baseUrl: string = "http://localhost:11434/api",
    curlPoolSize: int = 4,
    curlTimeout: float32 = 10000
): OllamaAPI =
  ## Initialize a new Ollama API client
  result = OllamaAPI()
  result.curlPool = newCurlPool(curlPoolSize)
  result.baseUrl = baseUrl
  result.curlTimeout = curlTimeout

proc close*(api: OllamaAPI) =
  api.curlPool.close()


proc loadModel*(api: OllamaAPI, model: string): JsonNode {.discardable.} =
  ## Calling /api/generate without a prompt will load the model
  let url = api.baseUrl / "generate"
  var headers: curly.HttpHeaders
  headers["Content-Type"] = "application/json"
  let req = %*{"model": model}

  let resp = api.curlPool.post(url, headers, toJson(req), api.curlTimeout)
  if resp.code != 200:
    raise newException(CatchableError, &"ollama failed to load model: {resp.code} {resp.body}")
  result = fromJson(resp.body)

proc generate*(api: OllamaAPI, req: GenerateReq): GenerateResp =
  ## typed interface for /api/generate
  let url = api.baseUrl / "generate"
  var headers: curly.HttpHeaders
  headers["Content-Type"] = "application/json"
  req.stream = option(false)
  let resp = api.curlPool.post(url, headers, toJson(req), api.curlTimeout)
  if resp.code != 200:
    raise newException(CatchableError, &"ollama generate failed: {resp.code} {resp.body}")
  result = fromJson(resp.body, GenerateResp)

proc generate*(api: OllamaAPI, model: string, prompt: string): string =
  ## simple interface for /api/generate
  let req = GenerateReq(model: model, prompt: prompt)
  let resp = api.generate(req)
  result = resp.response

proc generate*(api: OllamaAPI, req: JsonNode): JsonNode =
  ## direct json interface for /api/generate.
  ## only use if there are specific new features you need or know what you are doing
  let url = api.baseUrl / "generate"
  var headers: curly.HttpHeaders
  headers["Content-Type"] = "application/json"
  req["stream"] = newJBool(false)

  let resp = api.curlPool.post(url, headers, toJson(req), api.curlTimeout)
  if resp.code != 200:
    raise newException(CatchableError, &"ollama generate failed: {resp.code} {resp.body}")
  result = fromJson(resp.body)

proc chat*(api: OllamaAPI, req: ChatReq): ChatResp =
  ## typed interface for /api/chat
  let url = api.baseUrl / "chat"
  var headers: curly.HttpHeaders
  headers["Content-Type"] = "application/json"
  req.stream = option(false)
  let resp = api.curlPool.post(url, headers, toJson(req), api.curlTimeout)
  if resp.code != 200:
    raise newException(CatchableError, &"ollama chat failed: {resp.code} {resp.body}")
  result = fromJson(resp.body, ChatResp)

proc chat*(api: OllamaAPI, model: string, messages: seq[string]): string =
  ## simple interface for /api/chat.
  ## assuming alternating user -> assistant message history
  let req = ChatReq(model: model)
  var user = true
  for m in messages:
    req.messages.add(ChatMessage(role: if user: "user" else: "assistant", content: option(m)))
    user = not user
  let resp = api.chat(req)
  result = resp.message.content.get

proc chat*(api: OllamaAPI, req: JsonNode): JsonNode =
  ## direct json interface for /api/chat.
  ## only use if there are specific new features you need or know what you are doing
  let url = api.baseUrl / "chat"
  var headers: curly.HttpHeaders
  headers["Content-Type"] = "application/json"
  req["stream"] = newJBool(false)

  let resp = api.curlPool.post(url, headers, toJson(req), api.curlTimeout)
  if resp.code != 200:
    raise newException(CatchableError, &"ollama chat failed: {resp.code} {resp.body}")
  result = fromJson(resp.body)

proc createModel*(
  api: OllamaAPI,
  name: string,
  modelfile: string = "",
  path: string = ""
) =
  ## Create a model from a Modelfile
  ##
  ## (Recommended): set `modelfile` as the contents of your modelfile
  ## 
  ## (Alternative): set `path` to a server local path to a modelfile
  let url = api.baseUrl / "create"
  let req = CreateModelReq(
    name: name,
    modelfile: if modelfile == "": none(string) else: option(modelfile),
    path: if path == "": none(string) else: option(path),
    stream: false
  )

  var headers: curly.HttpHeaders
  headers["Content-Type"] = "application/json"

  let resp = api.curlPool.post(url, headers, toJson(req), api.curlTimeout)
  if resp.code != 200:
    raise newException(CatchableError, &"ollama create failed: {resp.code} {resp.body}")
  let respJson = fromJson(resp.body)
  let status = respJson["status"].getStr
  if status != "success":
    raise newException(CatchableError, &"ollama create bad status: {resp.body}")

proc listModels*(api: OllamaAPI): ListResp =
  ## List all the models available
  let url = api.baseUrl / "tags"
  let resp = api.curlPool.get(url, timeout = api.curlTimeout)
  if resp.code != 200:
    raise newException(CatchableError, &"ollama list tags failed: {resp.code} {resp.body}")
  result = fromJson(resp.body, ListResp)

proc showModel*(api: OllamaAPI, name: string): ShowModel =
  ## get details for a specific model
  let url = api.baseUrl / "show"
  let req = %*{"name": name}

  var headers: curly.HttpHeaders
  headers["Content-Type"] = "application/json"

  let resp = api.curlPool.post(url, headers, toJson(req), api.curlTimeout)
  if resp.code != 200:
    raise newException(CatchableError, &"ollama show failed: {resp.code} {resp.body}")
  result = fromJson(resp.body, ShowModel)

proc pullModel*(api: OllamaAPI, name: string) =
  ## Ask the ollama server to pull a model
  let url = api.baseUrl / "pull"
  let req = %*{"name": name, "stream": false}

  var headers: curly.HttpHeaders
  headers["Content-Type"] = "application/json"

  let resp = api.curlPool.post(url, headers, toJson(req), api.curlTimeout)
  if resp.code != 200:
    raise newException(CatchableError, &"ollama pull failed: {resp.code} {resp.body}")
  let respJson = fromJson(resp.body)
  let status = respJson["status"].getStr
  if status != "success":
    raise newException(CatchableError, &"ollama pull bad status: {resp.body}")

proc generateEmbeddings*(
  api: OllamaAPI,
  model: string,
  prompt: string,
  options: Option[ModelParameters] = none(ModelParameters)
): EmbeddingResp =
  ## Get the embeddings for a prompt
  let url = api.baseUrl / "embeddings"
  var req = EmbeddingReq(
    model: model,
    prompt: prompt,
    options: options
  )

  var headers: curly.HttpHeaders
  headers["Content-Type"] = "application/json"
  var resp = api.curlPool.post(url, headers, toJson(req), api.curlTimeout)
  if resp.code != 200:
    raise newException(CatchableError, &"ollama embedding failed: {resp.code} {resp.body}")

  # NB. the API has a bug where it will sometimes return `"embeddding": null`
  # https://github.com/jmorganca/ollama/issues/1707
  # seems related to switching model modes between requests
  # retrying the request appears to work around the issue.
  let resultJson = fromJson(resp.body)
  if resultJson["embedding"].kind == JNull:
    resp = api.curlPool.post(url, headers, toJson(req), api.curlTimeout)
    if resp.code != 200:
      raise newException(CatchableError,
          &"ollama embedding failed: {resp.code} {resp.body}")

    result = fromJson(resp.body, EmbeddingResp)
  else:
    result = fromJson(resp.body, EmbeddingResp)

# TODO: HEAD /api/blobs/:digest
# TODO: POST /api/blobs/:digest
# TODO: POST /api/copy
# TODO: DELETE /api/delete
# TODO: POST /api/push

proc getVersion*(api: OllamaAPI): string =
  ## get the current Ollama version
  let url = api.baseUrl / "version"
  let resp = api.curlPool.get(url, timeout = api.curlTimeout)
  if resp.code != 200:
    raise newException(CatchableError, &"ollama version failed: {resp.code} {resp.body}")
  let json = fromJson(resp.body)
  result = json["version"].getStr
