// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:signature/signature.dart';
import 'package:stove_transaction/agent/sales_form/widgets/custom_textfield.dart';
import 'package:stove_transaction/agent/sales_form/widgets/primary_button.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/form/controller/form_controller.dart';
import 'package:stove_transaction/form/ui/address_input_screen.dart';
import 'package:stove_transaction/core/constants/app_icons.dart';
import 'package:stove_transaction/core/constants/constants.dart';
import 'package:stove_transaction/shared/ui/custom_input_field.dart';
import 'dart:math';
import 'package:stove_transaction/shared/ui/number_input_formatter.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'dart:convert';

import 'package:stove_transaction/shared/widgets/base_app_bar.dart';
import 'package:stove_transaction/shared/widgets/page_header_tile.dart';

class UserForm extends StatefulWidget {
  @override
  State<UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<UserForm> {
  final FormController controller = Get.put(FormController());
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  String transactionId = _generateTransactionId();
  bool isSearchingAddress = false;
  // String? selectedState;
  // String? selectedLGA;
  File? stoveImage;
  File? agreedDocumentImage;
  late CameraController cameraController;
  late List<CameraDescription> _cameras;
  bool hasPermission = false;
  bool isCameraPreviewVisible = false; // Track camera preview visibility
  bool isStoveCpturing = false;
  late SignatureController
      signatureController; // Define the signatureController

  static String _generateTransactionId() {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  Future<void> _captureImage() async {
    try {
      final image = await cameraController.takePicture();
      setState(() {
        if (isStoveCpturing) {
          stoveImage = File(image.path);
        } else {
          agreedDocumentImage = File(image.path);
        }
      });
      resetCameraState(); // Reset camera state after capturing
    } catch (e) {
      print("Error capturing image: $e");
    }
  }

  Future<void> checkCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      hasPermission = true;
      await initializeCamera(false); // Use the rear camera by default
    } else {
      hasPermission = false;
      print('Camera permissions are denied');
      if (status.isPermanentlyDenied) {
        openAppSettings();
      }
    }
  }

  void resetCameraState() async {
    setState(() {
      isCameraPreviewVisible = false;
      hasPermission = false;
    });
    if (cameraController.value.isInitialized) {
      await cameraController.dispose();
    }
  }

  Future<void> initializeCamera(bool useFrontCamera) async {
    try {
      _cameras = await availableCameras();
      cameraController = CameraController(
        useFrontCamera
            ? _cameras.firstWhere(
                (camera) => camera.lensDirection == CameraLensDirection.front)
            : _cameras.firstWhere(
                (camera) => camera.lensDirection == CameraLensDirection.back),
        ResolutionPreset.max,
      );

      await cameraController.initialize();
      cameraController.setFlashMode(FlashMode.off);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  void closeSearchingAddress() {
    setState(() {
      isSearchingAddress = false;
    });
  }

  @override
  void initState() {
    super.initState();
    signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
    );
  }

  @override
  void dispose() {
    if (cameraController.value.isInitialized) {
      cameraController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // controller.isLoading.value = false;
    return Scaffold(
      appBar: BaseAppBar(
        showBottomBorder: false,
        onTaps: !isSearchingAddress
            ? () {
                Navigator.pop(context);
              }
            : () {
                setState(() {
                  isSearchingAddress = !isSearchingAddress;
                });
              },
      ),
      body: Obx(() {
        return controller.partnerNames.isEmpty
            ? Center(child: CircularProgressIndicator())
            : isCameraPreviewVisible &&
                    hasPermission &&
                    cameraController.value.isInitialized
                ? Container(
                    height: MediaQuery.of(context).size.height,
                    width: MediaQuery.of(context).size.width,
                    child: Stack(
                      children: [
                        Container(
                          height: MediaQuery.of(context).size.height,
                          width: MediaQuery.of(context).size.width,
                          child: cameraController.value.isInitialized
                              ? CameraPreview(cameraController)
                              : Center(child: CircularProgressIndicator()),
                        ),
                        Positioned(
                          bottom: 20,
                          left: MediaQuery.of(context).size.width / 2 - 30,
                          child: ElevatedButton(
                            onPressed: _captureImage,
                            child: Icon(Icons.camera_alt, size: 30),
                          ),
                        ),
                      ],
                    ),
                  )
                : isSearchingAddress
                    ? AddressInputScreen(
                        closeSearchingAddress: closeSearchingAddress,
                      )
                    : SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 16.0,
                            right: 16,
                            bottom: 16,
                          ),
                          child: Form(
                            key: formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                PageHeaderTile(
                                  title: 'New Sales',
                                  subtitle:
                                      'Capture sales details for your stove',
                                ),
                                SizedBox(height: 25),
                                Autocomplete<String>(
                                  optionsBuilder:
                                      (TextEditingValue textEditingValue) {
                                    if (textEditingValue.text.isEmpty) {
                                      return const Iterable<String>.empty();
                                    }
                                    return controller.stoveIds
                                        .where((String option) {
                                      return option.toLowerCase().contains(
                                          textEditingValue.text.toLowerCase());
                                    });
                                  },
                                  onSelected: (String selection) {
                                    controller.stoveSerialController.text =
                                        selection;
                                    setState(() {
                                      // This will trigger a rebuild and update the error state
                                    });
                                  },
                                  fieldViewBuilder: (
                                    BuildContext context,
                                    TextEditingController textEditingController,
                                    FocusNode focusNode,
                                    VoidCallback onFieldSubmitted,
                                  ) {
                                    return TextFormField(
                                      style: TextThemes(context).getTextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: AppColors.primaryColor,
                                      ),
                                      controller: textEditingController,
                                      focusNode: focusNode,
                                      decoration: InputDecoration(
                                        labelText: 'Stove Serial No.',
                                        labelStyle:
                                            TextThemes(context).getTextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: AppColors.primaryColor,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                        errorText: textEditingController
                                                    .text.isNotEmpty &&
                                                !controller.stoveIds.any((id) =>
                                                    id ==
                                                    textEditingController.text)
                                            ? 'Invalid Stove Serial No.'
                                            : null, // No error if valid or empty
                                      ),
                                      validator: (value) {
                                        if (value!.isNotEmpty &&
                                            !controller.stoveIds
                                                .any((id) => id == value)) {
                                          return 'Invalid Stove Serial No.';
                                        }
                                        return null; // No error
                                      },
                                      onChanged: (value) {
                                        setState(() {
                                          // This will trigger a rebuild and update the error state
                                        });
                                      },
                                    );
                                  },
                                ),
                                SizedBox(
                                  height: 5,
                                ),
                                CustomTextField(
                                  label: 'Transaction ID (Invoice Number)',
                                  controller: TextEditingController(
                                      text: transactionId),
                                  readOnly: true,
                                ),
                                CustomTextField(
                                  label: 'Sales Date',
                                  controller: controller.salesDateController,
                                  readOnly: true,
                                  onTap: () async {
                                    DateTime? pickedDate = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2101),
                                      builder: (BuildContext context,
                                          Widget? child) {
                                        return Theme(
                                          data: ThemeData.light().copyWith(
                                            primaryColor:
                                                AppColors.primaryColor,
                                            // accentColor: AppColors.primaryColor,
                                            colorScheme: ColorScheme.light(
                                                primary:
                                                    AppColors.primaryColor),
                                            buttonTheme: ButtonThemeData(
                                                textTheme:
                                                    ButtonTextTheme.primary),
                                          ),
                                          child: child ?? Container(),
                                        );
                                      },
                                    );
                                    if (pickedDate != null) {
                                      controller.salesDateController.text =
                                          "${pickedDate.toLocal()}"
                                              .split(' ')[0];
                                    }
                                  },
                                ),
                                CustomTextField(
                                  label: 'Contact Person / Buyer',
                                  controller:
                                      controller.contactPersonController,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Contact Person is required.';
                                    }
                                    return null; // No error
                                  },
                                ),
                                CustomTextField(
                                  label: 'Contact Person\'s Phone Number',
                                  controller: controller.contactPhoneController,
                                  inputType: TextInputType.phone,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Contact Person\'s Phone Number is required.';
                                    }
                                    return null; // No error
                                  },
                                ),
                                CustomTextField(
                                  label:
                                      'End User\'s Name (Surname / First name)',
                                  controller: controller.surnameController,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'End User\'s Name is required.';
                                    }
                                    return null; // No error
                                  },
                                ),
                                CustomTextField(
                                  label: 'Also Known As (AKA)',
                                  controller: controller.akaController,
                                ),
                                SizedBox(
                                  height: 10,
                                ),
                                DropdownButtonFormField<String>(
                                  style: TextThemes(context).getTextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: AppColors.primaryColor,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'State',
                                    labelStyle:
                                        TextThemes(context).getTextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: AppColors.primaryColor,
                                    ),
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(8.0)),
                                  ),
                                  items: lgaAndStates.keys.map((state) {
                                    return DropdownMenuItem<String>(
                                      value: state,
                                      child: Text(state),
                                    );
                                  }).toList(),
                                  value:
                                      controller.selectedState.value.isNotEmpty
                                          ? controller.selectedState.value
                                          : null,
                                  onChanged: (value) {
                                    setState(() {
                                      controller.selectedState.value =
                                          value ?? '';
                                      controller.selectedLGA.value =
                                          ''; // Reset LGA when state changes
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'State is required.';
                                    }
                                    return null; // No error
                                  },
                                ),
                                SizedBox(
                                  height: 20,
                                ),
                                DropdownButtonFormField<String>(
                                  style: TextThemes(context).getTextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: AppColors.primaryColor,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'LGA',
                                    labelStyle:
                                        TextThemes(context).getTextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: AppColors.primaryColor,
                                    ),
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(8.0)),
                                  ),
                                  items: controller
                                              .selectedState.value.isNotEmpty &&
                                          lgaAndStates.containsKey(
                                              controller.selectedState.value)
                                      ? lgaAndStates[
                                              controller.selectedState.value]!
                                          .map((lga) {
                                          return DropdownMenuItem<String>(
                                            value: lga,
                                            child: Text(lga),
                                          );
                                        }).toList()
                                      : [],
                                  value: controller.selectedLGA.value.isNotEmpty
                                      ? controller.selectedLGA.value
                                      : null,
                                  onChanged: (value) {
                                    setState(() {
                                      controller.selectedLGA.value =
                                          value ?? '';
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'LGA is required.';
                                    }
                                    return null; // No error
                                  },
                                ),
                                SizedBox(
                                  height: 10,
                                ),
                                CustomTextField(
                                  label: 'Residential Address',
                                  readOnly: true,
                                  onTap: () {
                                    setState(() {
                                      isSearchingAddress = true;
                                    });
                                  },
                                  controller: controller.addressController,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Residential Address is required.';
                                    }
                                    return null; // No error
                                  },
                                ),
                                SizedBox(
                                  child: controller.latitude != null
                                      ? Opacity(
                                          opacity: 0.4,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Text(
                                              //   'Note: For Debugging purposes only',
                                              //   overflow: TextOverflow.ellipsis,
                                              //   style: TextThemes(context)
                                              //       .getTextStyle(
                                              //     fontWeight: FontWeight.w400,
                                              //     fontSize: 13,
                                              //     color: AppColors.deepRed,
                                              //   ),
                                              // ),
                                              CustomTextField(
                                                label: 'Latitude',
                                                readOnly: true,
                                                controller:
                                                    TextEditingController(
                                                  text: controller.latitude
                                                      .toString(),
                                                ),
                                              ),
                                              CustomTextField(
                                                label: 'Longitude',
                                                readOnly: true,
                                                controller:
                                                    TextEditingController(
                                                  text: controller.longitude
                                                      .toString(),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : null,
                                ),
                                CustomTextField(
                                  label: 'Phone Number',
                                  controller: controller.phoneController,
                                  inputType: TextInputType.phone,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Phone Number is required.';
                                    }
                                    return null; // No error
                                  },
                                ),
                                CustomTextField(
                                  label: 'Other Number',
                                  controller: controller.otherPhoneController,
                                  inputType: TextInputType.phone,
                                ),
                                // DropdownButtonFormField<String>(
                                //   style: TextThemes(context).getTextStyle(
                                //     fontWeight: FontWeight.w600,
                                //     fontSize: 14,
                                //     color: AppColors.primaryColor,
                                //   ),
                                //   decoration: InputDecoration(
                                //     labelText: 'Partner Name',
                                //     labelStyle: TextThemes(context).getTextStyle(
                                //       fontWeight: FontWeight.w600,
                                //       fontSize: 14,
                                //       color: AppColors.primaryColor,
                                //     ),
                                //     border: OutlineInputBorder(
                                //         borderRadius: BorderRadius.circular(8.0)),
                                //   ),
                                //   items: controller.partnerNames.map((partner) {
                                //     return DropdownMenuItem<String>(
                                //       value: partner,
                                //       child: Text(partner),
                                //     );
                                //   }).toList(),
                                //   onChanged: (value) {
                                //     // Handle selection
                                //   },
                                // ),
                                CustomTextField(
                                  label: 'Amount',
                                  controller: controller.amountController,
                                  inputType: TextInputType.numberWithOptions(
                                      decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Amount',
                                    labelStyle:
                                        TextThemes(context).getTextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: AppColors.primaryColor,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    prefix: Text(
                                      'N',
                                      style: TextThemes(context).getTextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: AppColors.primaryColor,
                                      ),
                                    ),
                                  ),
                                  inputFormatters: [
                                    NumberInputFormatter(),
                                  ],
                                ),
                                SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Signature',
                                      style: TextThemes(context).getTextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: AppColors.primaryTextColor,
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        // Clear the signature
                                        signatureController.clear();
                                      },
                                      child: Text(
                                        'Clear',
                                        style: TextThemes(context).getTextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: AppColors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Signature(
                                  controller: signatureController,
                                  height: 150,
                                  backgroundColor: Colors.grey[200]!,
                                ),
                                SizedBox(height: 16),
                                SizedBox(
                                  child: stoveImage != null
                                      ? Flex(
                                          direction: Axis.horizontal,
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: AppColors.bgGrey,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: SizedBox(
                                                  width: 130,
                                                  height: 130,
                                                  child: Image.file(
                                                    stoveImage!,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 15,
                                            ),
                                            Flexible(
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 15,
                                                  horizontal: 10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.bgGrey,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Flex(
                                                  direction: Axis.horizontal,
                                                  children: [
                                                    Flexible(
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .start,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            'Picture of stove',
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: TextThemes(
                                                                    context)
                                                                .getTextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w400,
                                                              fontSize: 13,
                                                              color: AppColors
                                                                  .primaryTextColor,
                                                            ),
                                                          ),
                                                          Text(
                                                            'JPG, JEPG, PNG',
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: TextThemes(
                                                                    context)
                                                                .getTextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w400,
                                                              fontSize: 10,
                                                              color: AppColors
                                                                  .secondaryTextColor,
                                                            ),
                                                          ),
                                                          SizedBox(
                                                            height: 30,
                                                          ),
                                                          Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceBetween,
                                                            children: [
                                                              GestureDetector(
                                                                onTap:
                                                                    () async {
                                                                  await checkCameraPermission(); // Check camera permission
                                                                  if (hasPermission) {
                                                                    await initializeCamera(
                                                                        false); // Initialize camera on tap
                                                                    setState(
                                                                        () {
                                                                      isStoveCpturing =
                                                                          true;
                                                                      isCameraPreviewVisible =
                                                                          true; // Show camera preview
                                                                    });
                                                                  }
                                                                },
                                                                child:
                                                                    Container(
                                                                  padding:
                                                                      EdgeInsets
                                                                          .symmetric(
                                                                    vertical: 7,
                                                                    horizontal:
                                                                        13,
                                                                  ),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: AppColors
                                                                        .green
                                                                        .withOpacity(
                                                                            0.3),
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(
                                                                      100,
                                                                    ),
                                                                  ),
                                                                  child: Text(
                                                                    'Retake',
                                                                    style: TextThemes(
                                                                            context)
                                                                        .getTextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w400,
                                                                      fontSize:
                                                                          13,
                                                                      color: AppColors
                                                                          .green,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              GestureDetector(
                                                                onTap: () {
                                                                  setState(() {
                                                                    stoveImage =
                                                                        null;
                                                                  });
                                                                },
                                                                child:
                                                                    Container(
                                                                  padding:
                                                                      EdgeInsets
                                                                          .symmetric(
                                                                    vertical: 7,
                                                                    horizontal:
                                                                        13,
                                                                  ),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: AppColors
                                                                        .red
                                                                        .withOpacity(
                                                                            0.3),
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(
                                                                      100,
                                                                    ),
                                                                  ),
                                                                  child: Text(
                                                                    'Delete',
                                                                    style: TextThemes(
                                                                            context)
                                                                        .getTextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w400,
                                                                      fontSize:
                                                                          13,
                                                                      color: AppColors
                                                                          .red,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          )
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : GestureDetector(
                                          onTap: () async {
                                            await checkCameraPermission(); // Check camera permission
                                            if (hasPermission) {
                                              await initializeCamera(
                                                  false); // Initialize camera on tap
                                              setState(() {
                                                isStoveCpturing = true;
                                                isCameraPreviewVisible =
                                                    true; // Show camera preview
                                              });
                                            }
                                          },
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 15,
                                              horizontal: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.bgGrey,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Flex(
                                              direction: Axis.horizontal,
                                              children: [
                                                SvgPicture.asset(
                                                  AppIcons.imageIcon,
                                                ),
                                                SizedBox(
                                                  width: 15,
                                                ),
                                                Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.start,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Picture of stove',
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextThemes(context)
                                                          .getTextStyle(
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        fontSize: 13,
                                                        color: AppColors
                                                            .primaryTextColor,
                                                      ),
                                                    ),
                                                    Text(
                                                      'JPG, JEPG, PNG',
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextThemes(context)
                                                          .getTextStyle(
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        fontSize: 10,
                                                        color: AppColors
                                                            .secondaryTextColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                ),

                                SizedBox(height: 20),
                                SizedBox(
                                  child: agreedDocumentImage != null
                                      ? Flex(
                                          direction: Axis.horizontal,
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: AppColors.bgGrey,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: SizedBox(
                                                  width: 130,
                                                  height: 130,
                                                  child: Image.file(
                                                    agreedDocumentImage!,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 15,
                                            ),
                                            Flexible(
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 15,
                                                  horizontal: 10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.bgGrey,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Flex(
                                                  direction: Axis.horizontal,
                                                  children: [
                                                    Flexible(
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .start,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            'Picture of hard copy signed agreement',
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: TextThemes(
                                                                    context)
                                                                .getTextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w400,
                                                              fontSize: 13,
                                                              color: AppColors
                                                                  .primaryTextColor,
                                                            ),
                                                          ),
                                                          Text(
                                                            'JPG, JPEG, PNG',
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: TextThemes(
                                                                    context)
                                                                .getTextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w400,
                                                              fontSize: 10,
                                                              color: AppColors
                                                                  .secondaryTextColor,
                                                            ),
                                                          ),
                                                          SizedBox(
                                                            height: 30,
                                                          ),
                                                          Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceBetween,
                                                            children: [
                                                              GestureDetector(
                                                                onTap:
                                                                    () async {
                                                                  await checkCameraPermission(); // Check camera permission
                                                                  if (hasPermission) {
                                                                    await initializeCamera(
                                                                        false); // Initialize camera on tap
                                                                    setState(
                                                                        () {
                                                                      isStoveCpturing =
                                                                          false;
                                                                      isCameraPreviewVisible =
                                                                          true; // Show camera preview
                                                                    });
                                                                  }
                                                                },
                                                                child:
                                                                    Container(
                                                                  padding:
                                                                      EdgeInsets
                                                                          .symmetric(
                                                                    vertical: 7,
                                                                    horizontal:
                                                                        13,
                                                                  ),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: AppColors
                                                                        .green
                                                                        .withOpacity(
                                                                            0.3),
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(
                                                                      100,
                                                                    ),
                                                                  ),
                                                                  child: Text(
                                                                    'Retake',
                                                                    style: TextThemes(
                                                                            context)
                                                                        .getTextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w400,
                                                                      fontSize:
                                                                          13,
                                                                      color: AppColors
                                                                          .green,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              GestureDetector(
                                                                onTap: () {
                                                                  setState(() {
                                                                    agreedDocumentImage =
                                                                        null;
                                                                  });
                                                                },
                                                                child:
                                                                    Container(
                                                                  padding:
                                                                      EdgeInsets
                                                                          .symmetric(
                                                                    vertical: 7,
                                                                    horizontal:
                                                                        13,
                                                                  ),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: AppColors
                                                                        .red
                                                                        .withOpacity(
                                                                            0.3),
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(
                                                                      100,
                                                                    ),
                                                                  ),
                                                                  child: Text(
                                                                    'Delete',
                                                                    style: TextThemes(
                                                                            context)
                                                                        .getTextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w400,
                                                                      fontSize:
                                                                          13,
                                                                      color: AppColors
                                                                          .red,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          )
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : GestureDetector(
                                          onTap: () async {
                                            await checkCameraPermission(); // Check camera permission
                                            if (hasPermission) {
                                              await initializeCamera(
                                                  false); // Initialize camera on tap
                                              setState(() {
                                                isStoveCpturing = false;
                                                isCameraPreviewVisible =
                                                    true; // Show camera preview
                                              });
                                            }
                                          },
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 15,
                                              horizontal: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.bgGrey,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Flex(
                                              direction: Axis.horizontal,
                                              children: [
                                                SvgPicture.asset(
                                                  AppIcons.imageIcon,
                                                ),
                                                SizedBox(
                                                  width: 15,
                                                ),
                                                Expanded(
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.start,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Picture of hard copy signed agreement',
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style:
                                                            TextThemes(context)
                                                                .getTextStyle(
                                                          fontWeight:
                                                              FontWeight.w400,
                                                          fontSize: 13,
                                                          color: AppColors
                                                              .primaryTextColor,
                                                        ),
                                                      ),
                                                      Text(
                                                        'JPG, JPEG, PNG',
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style:
                                                            TextThemes(context)
                                                                .getTextStyle(
                                                          fontWeight:
                                                              FontWeight.w400,
                                                          fontSize: 10,
                                                          color: AppColors
                                                              .secondaryTextColor,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                ),
                                SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: PrimaryButton(
                                    onPressed: controller.isLoading.value
                                        ? () {}
                                        : () async {
                                            setState(() {
                                              controller.transactionIdController
                                                  .text = transactionId;
                                              controller.stateController.text =
                                                  controller
                                                      .selectedState.value!;
                                              controller.lgaController.text =
                                                  controller.selectedLGA.value!;
                                            });

                                            String? signature =
                                                await _getSignature(); // Get the signature

                                            if (formKey.currentState!
                                                .validate()) {
                                              // Show loading indicator
                                              Get.snackbar(
                                                'Loading',
                                                'Submitting your form...',
                                                snackPosition:
                                                    SnackPosition.BOTTOM,
                                                backgroundColor:
                                                    Color(0x71817904),
                                                colorText: AppColors.white,
                                                duration: Duration(seconds: 7),
                                              );

                                              // Call the submitForm method from the controller
                                              await controller.handleSaleSubmit(
                                                stoveImage,
                                                agreedDocumentImage,
                                                signature,
                                              );

                                              // Clear the form and generate a new transaction ID
                                              formKey.currentState!.reset();
                                              transactionId =
                                                  _generateTransactionId();
                                              controller.selectedState.value =
                                                  '';
                                              controller.selectedLGA.value = '';
                                              stoveImage = null;
                                              agreedDocumentImage = null;
                                              controller.street = null;
                                              controller.city = null;
                                              controller.state = null;
                                              controller.country = null;
                                              controller.latitude = null;
                                              controller.longitude = null;
                                              controller.transactionIdController
                                                  .clear();
                                              controller.stateController
                                                  .clear();
                                              controller.lgaController.clear();
                                              controller.salesDateController
                                                  .clear();
                                              controller.contactPersonController
                                                  .clear();
                                              controller.contactPhoneController
                                                  .clear();
                                              controller.surnameController
                                                  .clear();
                                              controller.akaController.clear();
                                              controller.addressController
                                                  .clear();
                                              controller.phoneController
                                                  .clear();
                                              controller.otherPhoneController
                                                  .clear();
                                              controller.amountController
                                                  .clear();
                                              signatureController.clear();
                                            } else {
                                              Get.snackbar(
                                                'Error',
                                                'Please ensure all fields are valid.',
                                                backgroundColor:
                                                    Color(0x71810404),
                                                duration: Duration(seconds: 5),
                                                colorText: AppColors.white,
                                                snackPosition:
                                                    SnackPosition.BOTTOM,
                                              );
                                            }
                                          },
                                    isLoading: controller.isLoading.value,
                                    text: "Submit",
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
      }),
    );
  }

  Future<String?> _getSignature() async {
    if (signatureController.isNotEmpty) {
      final data = await signatureController.toPngBytes();
      return base64Encode(data!);
    }
    return null;
  }
}

class ImageViewPage extends StatelessWidget {
  final String imagePath;

  const ImageViewPage({Key? key, required this.imagePath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Captured Image'),
      ),
      body: Center(
        child: Image.file(File(imagePath)),
      ),
    );
  }
}
