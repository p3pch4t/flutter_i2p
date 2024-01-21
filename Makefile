I2PD_TAG=2.50.2RC4
VERSION=2.50.2

.PHONY: version
version:
	sed -i "s/^version: .*/version: ${VERSION}+$(shell git rev-list --count HEAD)/" "pubspec.yaml"

libs: android/src/main/jniLibs/arm64-v8a/i2pd
.PHONY: android/src/main/jniLibs/arm64-v8a/i2pd
android/src/main/jniLibs/arm64-v8a/i2pd:
	wget -q https://git.mrcyjanek.net/p3pch4t/i2pd-build/releases/download/${I2PD_TAG}/aarch64-linux-android_i2pd.xz -O android/src/main/jniLibs/arm64-v8a/i2pd.xz
	unxz android/src/main/jniLibs/arm64-v8a/i2pd.xz
	mv android/src/main/jniLibs/arm64-v8a/i2pd android/src/main/jniLibs/arm64-v8a/libi2pd.so

libs: android/src/main/jniLibs/armeabi-v7a/i2pd
.PHONY: android/src/main/jniLibs/armeabi-v7a/i2pd
android/src/main/jniLibs/armeabi-v7a/i2pd:
	wget -q https://git.mrcyjanek.net/p3pch4t/i2pd-build/releases/download/${I2PD_TAG}/arm-linux-androideabi_i2pd.xz -O android/src/main/jniLibs/armeabi-v7a/i2pd.xz
	unxz android/src/main/jniLibs/armeabi-v7a/i2pd.xz
	mv android/src/main/jniLibs/armeabi-v7a/i2pd android/src/main/jniLibs/armeabi-v7a/libi2pd.so

libs: android/src/main/jniLibs/x86/i2pd
.PHONY: android/src/main/jniLibs/x86/i2pd
android/src/main/jniLibs/x86/i2pd:
	wget -q https://git.mrcyjanek.net/p3pch4t/i2pd-build/releases/download/${I2PD_TAG}/i686-linux-android_i2pd.xz -O android/src/main/jniLibs/x86/i2pd.xz
	unxz android/src/main/jniLibs/x86/i2pd.xz
	mv android/src/main/jniLibs/x86/i2pd android/src/main/jniLibs/x86/libi2pd.so

libs: android/src/main/jniLibs/x86_64/i2pd
.PHONY: android/src/main/jniLibs/x86_64/i2pd
android/src/main/jniLibs/x86_64/i2pd:
	wget -q https://git.mrcyjanek.net/p3pch4t/i2pd-build/releases/download/${I2PD_TAG}/x86_64-linux-android_i2pd.xz -O android/src/main/jniLibs/x86_64/i2pd.xz
	unxz android/src/main/jniLibs/x86_64/i2pd.xz
	mv android/src/main/jniLibs/x86_64/i2pd android/src/main/jniLibs/x86_64/libi2pd.so

clean:
	-rm android/src/main/jniLibs/x86_64/*
	-rm android/src/main/jniLibs/armeabi-v7a/*
	-rm android/src/main/jniLibs/x86/*
	-rm android/src/main/jniLibs/arm64-v8a/*
