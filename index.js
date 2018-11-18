
import { NativeModules } from 'react-native'
import { validateOpts, requireOpts } from './validate'

const { RNTradleKeeper } = NativeModules
const DEFAULT_OPTS = {
  digestAlgorithm: 'sha256',
  encoding: 'base64',
}

export default class Keeper {
  constructor(defaults) {
    this.opts = {
      ...DEFAULT_OPTS,
      ...defaults,
    }

    validateOpts(this.opts)
  }

  normalizeAndValidateOpts(opts) {
    opts = { ...this.opts, ...opts }
    validateOpts(opts)
    return opts
  }

  async put(opts) {
    opts = this.normalizeAndValidateOpts(opts)
    requireOpts(opts, ['key', 'value', 'encryptionKey', 'hmacKey'])
    return RNTradleKeeper.put(this.normalizeAndValidateOpts(opts))
  }

  async get(opts) {
    opts = this.normalizeAndValidateOpts(opts)
    requireOpts(opts, ['key', 'encryptionKey', 'hmacKey'])
    if (!(opts.addToImageStore || opts.returnBase64)) {
      throw new Error(`expected "addToImageStore" or "returnBase64" to be true`)
    }

    return RNTradleKeeper.get(opts)
  }

  async prefetch(opts) {
    opts = this.normalizeAndValidateOpts({ ...opts, addToImageStore: true, returnBase64: false })
    requireOpts(opts, ['key', 'encryptionKey', 'hmacKey'])
    return RNTradleKeeper.get(opts)
  }

  async importFromImageStore(opts) {
    opts = this.normalizeAndValidateOpts(opts)
    requireOpts(opts, ['imageTag', 'encryptionKey', 'hmacKey'])
    return RNTradleKeeper.importFromImageStore(opts)
  }

  async removeFromImageStore(opts) {
    opts = this.normalizeAndValidateOpts(opts)
    requireOpts(opts, ['imageTag'])
    return RNTradleKeeper.removeFromImageStore(opts)
  }

  async test() {
    return RNTradleKeeper.test()
  }
}

export const create = opts => new Keeper(opts)
