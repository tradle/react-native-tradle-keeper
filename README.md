
# react-native-tradle-keeper

## Getting started

`$ npm install react-native-tradle-keeper --save`

### Mostly automatic installation

`$ react-native link react-native-tradle-keeper`

### Manual installation

#### iOS

1. In XCode, in the project navigator, right click `Libraries` ➜ `Add Files to [your project's name]`
2. Go to `node_modules` ➜ `react-native-tradle-keeper` and add `RNTradleKeeper.xcodeproj`
3. In XCode, in the project navigator, select your project. Add `libRNTradleKeeper.a` to your project's `Build Phases` ➜ `Link Binary With Libraries`
4. Run your project (`Cmd+R`)<

#### Android

1. Open up `android/app/src/main/java/[...]/MainActivity.java`
  - Add `import io.tradle.keeper.RNTradleKeeperPackage;` to the imports at the top of the file
  - Add `new RNTradleKeeperPackage()` to the list returned by the `getPackages()` method
2. Append the following lines to `android/settings.gradle`:
  	```
  	include ':react-native-tradle-keeper'
  	project(':react-native-tradle-keeper').projectDir = new File(rootProject.projectDir, 	'../node_modules/react-native-tradle-keeper/android')
  	```
3. Insert the following lines inside the dependencies block in `android/app/build.gradle`:
  	```
      compile project(':react-native-tradle-keeper')
  	```


## Usage

```js
import Keeper from 'react-native-tradle-keeper';

const playWithKeeper = async () => {
  // import a data url from ImageStore
  const keeper = new Keeper({ namespace })
  await Keeper.importFromImageStore({ imageTag })
}
```

```objective-c
Keeper keeper = [RNKeeper keeperWithNamespace: namespace];
[keeper importFromImageStore:imageTag];
```

```java
Keeper keeper = RNKeeper.getKeeperWithNamespace(namespace);
keeper.importFromImageStore(imageTag);
```
