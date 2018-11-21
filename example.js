import Keeper from 'react-native-tradle-keeper'
import ImagePicker from 'react-native-image-picker'

const sha256 = buffer => {
  // not covered in this example
  return buffer
}

// store regular data
const keeper = new Keeper({
  // set the default opts
  encryptionKey: '321771419b82d51bde71f4bffe27e5235455c49641442d36093b4ee80bbe54a9',
  hmacKey: 'acb519c0f7d79958f133172d48e24ae8c38b7ab128ceded9082b54a307b4e838',
  digestAlgorithm: 'sha256',
  encoding: 'base64',
})

const snap = opts => new Promise((resolve, reject) => {
  ImagePicker.launchCamera(opts, ({ error, didCancel, ...result }) => {
    if (error || didCancel) {
      return reject(new Error(error || 'user canceled'))
    }

    resolve(result)
  })
})

const regularDataExample = async () => {
  const value = 'someString'
  const key = sha256(value)
  await keeper.put({ key, value, encoding: 'utf8' })
  const result = await keeper.get({ key })
  console.log(result.value) // original value
}

// save image from JS, serve from cache
const imageDataLowPerfExample = async () => {
  // data is a base64 string,
  // expensive to transfer over the bridge
  // ideally, you're adding to react-native-image-store on the native side,
  // as shown in next example
  const { data } = await snap({ /*...some opts...*/ })
  const key = sha256(data)
  await keeper.put({
    key,
    value: data,
    encoding: 'base64',
    addToImageStore: true,
  })

  // later:
  const result = await keeper.get({
    key,
    returnBase64: false,
    addToImageStore: true,
  })

  // uri for cached image,
  // cache is cleared on app restart
  console.log(result.imageTag)
}

// save image via native, server from cache
const imageDataHighPerfExample = async () => {
  // tradle/react-native-image-picker fork
  const { imageTag } = await snap({
    quality: 1,
    imageFileType: 'png',
    addToImageStore: true,
    noData: true,
    storageOptions: {
      // forceLocal: true,
      store: false,
    }
  })

  this.setState({
    uri: imageTag,
  })

  // copy over from react-native-image-store
  const { key } = await keeper.importFromImageStore({ imageTag })
  // use "key" if you need to get()
}
