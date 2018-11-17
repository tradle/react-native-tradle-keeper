
// store regular data
const keeper = new Keeper({
  // set the default opts
  encryptionKey: '321771419b82d51bde71f4bffe27e5235455c49641442d36093b4ee80bbe54a9',
  hmacKey: 'acb519c0f7d79958f133172d48e24ae8c38b7ab128ceded9082b54a307b4e838',
  digestAlgorithm: 'sha256',
  encoding: 'base64',
})

const regularDataExample = async () =>
  const value = 'someBase64String'
  const key = sha256OfValue
  await keeper.put({
    key: sha256OfValue,
    value: value,
    // addToImageStore: true,
    // target: Keeper.target.imageCache,
  })

  const result = await keeper.get({
    key: sha256OfValue
  })

  console.log(result.base64) // original value
}

// save image from JS, serve from cache
const imageDataLowPerfExample = async () =>
  const value = 'imageBase64'
  const key = sha256OfValue

  await new Promise((resolve, reject) => ImagePicker.launchCamera({}, ({ error, })))

  // ideally, you're adding to react-native-image-store on the native side,
  // as shown in next example
  await keeper.put({
    key: sha256OfValue,
    value: value,
    addToImageStore: true,
  })

  // later:
  const result = await keeper.get({
    key: sha256OfValue,
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
  const { imageTag } = await new Promise((resolve, reject) => ImagePicker.launchCamera({
    quality: 1,
    imageFileType: 'png',
    addToImageStore: true,
    noData: true,
    storageOptions: {
      // forceLocal: true,
      store: false,
    }
  }, ({ error, didCancel, ...result }) => {
    if (error || didCancel) {
      return reject(new Error(error || 'user canceled'))
    }

    resolve(result)
  }))

  this.setState({
    uri: imageTag,
  })

  // copy over from react-native-image-store
  const { key } = await keeper.importFromImageStore({ imageTag })
  // use "key" if you need to get()
}
