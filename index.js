
import { NativeModules } from 'react-native'
import { validateOpts, requireOpts } from './validate'
import Errors from './errors'

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
    if (!(opts.addToImageStore || opts.returnValue)) {
      throw new Error(`expected "addToImageStore" or "returnValue" to be true`)
    }

    try {
      return await RNTradleKeeper.get(opts)
    } catch (err) {
      throw Errors.interpret(err)
    }
  }

  async prefetch(opts) {
    opts = this.normalizeAndValidateOpts({ ...opts, addToImageStore: true, returnValue: false })
    requireOpts(opts, ['key', 'encryptionKey', 'hmacKey'])
    try {
      return await RNTradleKeeper.get(opts)
    } catch (err) {
      throw Errors.interpret(err)
    }
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
export { Errors }
