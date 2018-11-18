
const ADDITIONAL_PROPS = ['nativeStackIOS']
const copyAdditionalProps = (source, target) => ADDITIONAL_PROPS.forEach(prop => {
  if (prop in source) target[prop] = source[prop]
})

export class NotFound extends Error {
  name = 'NotFound'
  constructor(key, message) {
    super(message)
    this.key = key
  }
}

export const interpret = err => {
  let result
  if (err.code === 'not_found') {
    result = new NotFound(err.message)
  } else {
    return err
  }

  copyAdditionalProps(err, result)
  return result
}
