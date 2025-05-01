# thin-edge.io image using Rugix

The repository can be used to build custom device images with thin-edge.io and [Rugix](https://oss.silitics.com/rugix/) for robust Over-The-Air (OTA) Operating System updates.

## Compatible devices

Rugix can support building images for other devices than just Raspberry Pi's, however the thin-edge.io integration is currently only tested for Raspberry Pi devices. Please reach out for support if you are looking into integrating with other devices, or contact [Silitics](https://oss.silitics.com/rugix/commercial-support), the authors of Rugix.

**Using u-boot**

* Raspberry PI 1B
* Raspberry PI 2B Rev 1.2
* Raspberry PI Zero
* Raspberry PI Zero 2 W
* Raspberry PI 3

**Using tryboot**

* Raspberry Pi 4
* Raspberry Pi 5


## System Images

The following system images are included in this repository.

|Image|Description|
|-------|-----------|
|tedge-raspios-arm64-tryboot|Image for Raspberry Pi 4 and 5 devices which use the tryboot bootloader|
|tedge-raspios-arm64-tryboot-pi4|Raspberry Pi 4 image which includes the firmware to enable tryboot bootloader|
|tedge-raspios-arm64|Image for Raspberry Pi 3 and zero 2W|
|tedge-raspios-armhf|Image for Raspberry Pi 1, 2 and zero|
|tedge-raspios-armhf|Image for Raspberry Pi 1, 2 and zero|
|tedge-debian-12-efi-arm64|Image for an EFI enabled device with arm64|
|tedge-debian-12-efi-amd64|Image for an EFI enabled device with amd64|

## Building

### Building an image

To run the build tasks, install [just](https://just.systems/man/en/chapter_5.html).

1. Clone the repository

    ```sh
    git clone https://github.com/thin-edge/tedge-rugix-image.git
    ```

2. Create a custom `.env` file which will be used to store secrets

    ```sh
    cp env.template .env
    ```

    The `.env` file will not be committed to the repo

3. Edit the `.env` file

    If your device does not have an ethernet adapter, or you the device to connect to a Wifi network for onboarding, then you will have to add the Wifi credentials to the `.env` file.

    ```sh
    SECRETS_WIFI_SSID=example
    SECRETS_WIFI_PASSWORD=yoursecurepassword
    SSH_KEYS_bootstrap="ssh-rsa xxxxxxx"

    # Include ssh keys from github user profiles
    SSH_GITHUB_USERS=myuser
    ```

    **Note**

    The Wifi credentials only need to be included in the image that is flashed to the SD card. Subsequent images don't need to included the Wifi credentials, as the network connection configuration files are persisted across images.

    If an image has Wifi credentials baked in, then you should not make this image public, as it would expose your credentials! 

4. Create the image

    ```sh
    just SYSTEM=tedge-raspios-arm64-tryboot build-image
    ```

5. Using the path to the image shown in the console to flash the image to the device.

6. Build the update bundle for Over-the-Air Updates

    ```
    just SYSTEM=tedge-raspios-arm64-tryboot build-bundle
    ```

    **Note:** A Rugix update bundle will have the `.rugixb` suffix in its filename

For further information on Rugix, checkout the [quick start guide](https://oss.silitics.com/rugix/docs/getting-started).


### Building images/bundles including thin-edge.io main

To build an image with the latest pre-release version from the [main channel](https://thin-edge.github.io/thin-edge.io/contribute/package-hosting/#pre-releases), set the following environment variable in the `.env` file in your project:

```sh
# thin-edge.io install channel. Options: "main",  "release" (latest official release)
TEDGE_INSTALL_CHANNEL=main
```

### Building for your specific device type

The different image options can be confusing, so to help users a few device specific tasks were created to help you pick the correct image.

#### Raspberry Pi 1

```sh
just SYSTEM=tedge-raspios-armhf build-image
```

#### Raspberry Pi 2

```sh
just SYSTEM=tedge-raspios-armhf build-image
```

#### Raspberry Pi 3

```sh
just SYSTEM=tedge-raspios-arm64 build-image
```

#### Raspberry Pi 4 / 400

```sh
just SYSTEM=tedge-raspios-arm64 build-image
```

**Note**

All Raspberry Pi 4 and 400 don't support tryboot by default, and need their firmware updated before the `tryboot` image can be used.

You can build an image which also includes the firmware used to enable tryboot. Afterwards you can switch back to using an image without the firmware included in it.

```sh
just SYSTEM=tedge-raspios-arm64-tryboot-pi4 build-image
```

#### Raspberry Pi 5

```sh
just SYSTEM=tedge-raspios-arm64 build-image
```

#### Raspberry Pi Zero

```sh
just SYSTEM=tedge-raspios-armhf build-image
```

#### Raspberry Pi Zero 2W

```sh
just SYSTEM=tedge-raspios-arm64 build-image
```

## Project Tasks

### Publishing a new release

1. Ensure you have everything that you want to include in your image

2. Trigger a release by using the following task:

    ```
    just release
    ```

    Take note of the git tag which is created as you will need this later if you want to add the firmware to the Cumulocity IoT firmware repository

3. Wait for the Github action to complete

4. Edit the newly created release in the Github Releases section of the repository

5. Publish the release

**Optional: Public images to Cumulocity IoT**

You will need [go-c8y-cli](https://goc8ycli.netlify.app/) and [gh](https://cli.github.com/) tools for this!

1. In the console, using go-c8y-cli, set your session to the tenant where you want to upload the firmware to

    ```sh
    set-session mytenant
    ```

2. Assuming you are still in the project's root directory

    Using the release tag created in the previous step, run the following:

    ```sh
    just publish-external <TAG>
    ```

    Example

    ```sh
    just publish-external 20231206.0800
    ```

    This script will create firmware items (name and version) in Cumulocity IoT. The firmware versions will be just links to the external artifacts which are available from the Github Release artifacts.

3. Now you can select the firmware in Cumulocity IoT to deploy to your devices (assuming you have flashed the base image to the device first ;)!

## Add SSH and/or wifi to Github workflow

You can customize the images built by the Github workflow by creating a secret within Github.

1. Create a repository secret with the following settings

    **Name**
    
    ```sh
    IMAGE_CONFIG
    ```

    **Value**

    ```sh
    SSH_KEYS_bootstrap="ssh-rsa xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx bootstrap"
    SSH_KEYS_seconduser="ssh-rsa xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx myseconduser"
    ```

    Remove any lines which are not applicable to your build.

2. Build the workflow from Github using the UI (or creating a new git tag)
