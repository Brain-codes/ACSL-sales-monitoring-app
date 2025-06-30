// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/form/controller/form_controller.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';

import 'package:stove_transaction/shared/ui/custom_input_field.dart';
import 'package:google_place/google_place.dart';

class AddressInputScreen extends StatefulWidget {
  final void Function() closeSearchingAddress;
  const AddressInputScreen({
    super.key,
    required this.closeSearchingAddress,
  });

  @override
  State<AddressInputScreen> createState() => _AddressInputScreenState();
}

class _AddressInputScreenState extends State<AddressInputScreen> {
  final FormController controller = Get.put(FormController());
  final TextEditingController _searchController = TextEditingController();
  late GooglePlace googlePlace;
  List<AutocompletePrediction> predictions = [];

  @override
  void initState() {
    super.initState();
    googlePlace = GooglePlace("REMOVED_GOOGLE_API_KEY");
  }

  void autoCompleteSearch(String value) async {
    var result = await googlePlace.autocomplete.get(value);
    if (result != null && result.predictions != null) {
      setState(() {
        predictions = result.predictions!;
      });
    }
  }

  void fetchPlaceDetails(String placeId) async {
    var details = await googlePlace.details.get(placeId);
    if (details != null && details.result != null) {
      var result = details.result!;
      var addressComponents = result.addressComponents;
      var geometry = result.geometry;

      String? street, city, state, country;
      double? latitude, longitude;

      if (addressComponents != null) {
        for (var component in addressComponents) {
          var types = component.types;
          if (types != null) {
            if (types.contains('route')) {
              street = component.longName;
            } else if (types.contains('locality')) {
              city = component.longName;
            } else if (types.contains('administrative_area_level_1')) {
              state = component.longName;
            } else if (types.contains('country')) {
              country = component.longName;
            }
          }
        }
      }

      // Fallback logic
      street ??= city ?? state ?? country;
      city ??= state ?? country;
      state ??= country;

      if (geometry != null && geometry.location != null) {
        latitude = geometry.location!.lat;
        longitude = geometry.location!.lng;
      }

      // Update the FormController with the address details
      controller.street = street;
      controller.city = city;
      controller.state = state;
      controller.country = country;
      controller.latitude = latitude;
      controller.longitude = longitude;

      print({
        "fullAddress": result.formattedAddress,
        "street": street,
        "city": city,
        "state": state,
        "country": country,
        "latitude": latitude,
        "longitude": longitude,
      });
      setState(() {
        controller.addressController.text = result.formattedAddress ?? '';
      });
      widget.closeSearchingAddress();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 15,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
          ),
          child: CustomInputField(
            label: 'Address',
            controller: _searchController,
            inputType: TextInputType.text,
            onChanged: (value) {
              if (value.isNotEmpty) {
                autoCompleteSearch(value);
              } else {
                setState(() {
                  predictions = [];
                });
              }
            },
          ),
        ),
        SizedBox(
          height: 15,
        ),
        Expanded(
          child: SizedBox(
            child: predictions.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                      ),
                      child: Text(
                        'No Location selected, please select closest landmark if exact location not available',
                        // overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextThemes(context).getTextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                    ),
                    child: ListView.builder(
                      itemCount: predictions.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            fetchPlaceDetails(predictions[index].placeId!);
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(
                              bottom: 12,
                            ),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                vertical: 9,
                                horizontal: 7,
                              ),
                              decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  border: Border.all(
                                    width: 0.4,
                                    color: AppColors.primaryColor,
                                  ),
                                  borderRadius: BorderRadius.circular(8)),
                              child: Flex(
                                direction: Axis.horizontal,
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    color: AppColors.primaryColor,
                                  ),
                                  SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      predictions[index].description ?? '',
                                      // overflow: TextOverflow.ellipsis,
                                      style: TextThemes(context).getTextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: AppColors.primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
