import curly, jsony, std/[strutils, json, options, strformat, os]

## ollama API Interface
## https://github.com/jmorganca/ollama/blob/main/docs/api.md
## https://github.com/jmorganca/ollama/blob/main/api/types.go

## model parameters: https://github.com/jmorganca/ollama/blob/main/docs/modelfile.md#valid-parameters-and-values

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
  GenerateReq* = ref object
    model*: string
    prompt*: string
    images*: Option[seq[string]]      # list of base64 encoded images
    format*: Option[string]           # optional format=json for a structured response
    options*: Option[ModelParameters] # bag of model parameters
    system*: Option[string]           # override modelfile system prompt
    template_str*: Option[string]     # override modelfile template
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
  ModelDetails* = ref object
    format: string
    family: string
    families: Option[seq[string]]
    parameter_size: string
    quantization_level: string
  OllamaModel* = ref object
    name*: string
    modified_at*: string
    size: int
    digest: string
    details*: ModelDetails
  ListResp* = ref object
    models*: seq[OllamaModel]
  EmbeddingReq* = ref object
    model*: string
    prompt*: string
    options*: Option[ModelParameters] # bag of model parameters
  EmbeddingResp* = ref object
    embedding*: seq[float64]

proc renameHook*(v: var GenerateReq, fieldName: var string) =
  ## `template` is a special keyword in nim, so we need to rename it during serialization
  if fieldName == "template":
    fieldName = "template_str"
proc dumpHook*(v: var GenerateReq, fieldName: var string) =
  if fieldName == "template_str":
    fieldName = "template"

proc dumpHook*(s: var string, v: object) =
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
  ## direct json interface for /api/generate
  ## only use if there are specific new features you need or know what you are doing
  let url = api.baseUrl / "generate"
  var headers: curly.HttpHeaders
  headers["Content-Type"] = "application/json"
  req["stream"] = newJBool(false)

  let resp = api.curlPool.post(url, headers, toJson(req), api.curlTimeout)
  if resp.code != 200:
    raise newException(CatchableError, &"ollama generate failed: {resp.code} {resp.body}")
  result = fromJson(resp.body)

proc listModels*(api: OllamaAPI): ListResp =
  ## List all the models available
  let url = api.baseUrl / "tags"
  let resp = api.curlPool.get(url, timeout = api.curlTimeout)
  if resp.code != 200:
    raise newException(CatchableError, &"ollama list tags failed: {resp.code} {resp.body}")
  result = fromJson(resp.body, ListResp)

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

  let resp = api.curlPool.post(url, headers, toJson(req), api.curlTimeout)
  if resp.code != 200:
    raise newException(CatchableError, &"ollama embedding failed: {resp.code} {resp.body}")
  result = fromJson(resp.body, EmbeddingResp)
