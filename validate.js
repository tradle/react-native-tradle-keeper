
const HEX_ALPHABET = '0123456789abcdef'
const is32ByteHex = val => typeof val === 'string' &&
  val.length === 64 &&
  isHex(val)

const isHex = val => val.toLowerCase().split('').every(ch => HEX_ALPHABET.includes(ch))
const oneOf = vals => val => vals.includes(val)

const createTypeValidator = type => val => typeof val === type
const typeValidators = {
  boolean: createTypeValidator('boolean'),
  string: createTypeValidator('string'),
}

const validators = {
  key: typeValidators.string,
  value: typeValidators.string,
  imageTag: typeValidators.string,
  encoding: oneOf(['utf8', 'base64']),
  digestAlgorithm: oneOf(['md5', 'sha1', 'sha224', 'sha256', 'sha384', 'sha512']),
  encryptionKey: is32ByteHex,
  hmacKey: is32ByteHex,
  addToImageStore: typeValidators.boolean,
  returnBase64: typeValidators.boolean,
  hashInput: oneOf(['valueBytes', 'dataUrlForValue']),
}

export const validateOpts = opts => Object.keys(opts).forEach(key => {
  const validate = validators[key]
  if (!validate) {
    throw new Error(`unknown option: ${key}`)
  }

  const val = opts[key]
  if (!validate(val)) {
    throw new Error(`invalid value for option "${key}"`)
  }
})

export const requireOpts = (opts, names) => {
  const missing = names.filter(name => !opts[name])
  if (missing.length) {
    throw new Error(`missing required options: ${missing.join(', ')}`)
  }
}
