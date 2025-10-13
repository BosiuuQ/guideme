import 'dart:io';
import 'package:flutter/material.dart';
import 'package:guide_me/core/constants/app_colors.dart';
import 'package:guide_me/core/presentation/widgets/card_widget.dart';
import 'package:guide_me/core/presentation/widgets/custom_text_form_field_widget.dart';
import 'package:guide_me/core/presentation/widgets/unfocus_on_tap_wrapper.dart';
import 'package:guide_me/features/garage/domain/entity/vehicle.dart';
import 'package:guide_me/features/garage/garage_backend.dart';
import 'package:image_picker/image_picker.dart';

class AddNewVehicleView extends StatefulWidget {
  const AddNewVehicleView({super.key});

  @override
  State<AddNewVehicleView> createState() => _AddNewVehicleViewState();
}

class _AddNewVehicleViewState extends State<AddNewVehicleView> {
  final ImagePicker _picker = ImagePicker();
  final List<XFile> vehicleImages = [];
  late PageController _pageController;
  final _formKey = GlobalKey<FormState>();
  bool isSaving = false;

  final TextEditingController brandCtrl = TextEditingController();
  final TextEditingController modelCtrl = TextEditingController();
  final TextEditingController horsepowerCtrl = TextEditingController();
  final TextEditingController capacityCtrl = TextEditingController();
  final TextEditingController yearCtrl = TextEditingController();
  final TextEditingController colorCtrl = TextEditingController();
  final TextEditingController fuelCtrl = TextEditingController();
  final TextEditingController gearboxCtrl = TextEditingController();
  final TextEditingController driveCtrl = TextEditingController();
  final TextEditingController noteCtrl = TextEditingController();

  @override
  void initState() {
    _pageController = PageController(viewportFraction: 0.9);
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    brandCtrl.dispose();
    modelCtrl.dispose();
    horsepowerCtrl.dispose();
    capacityCtrl.dispose();
    yearCtrl.dispose();
    colorCtrl.dispose();
    fuelCtrl.dispose();
    gearboxCtrl.dispose();
    driveCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UnfocusOnTapWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Dodaj nowy pojazd"),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                children: [
                  _imagesSection(),
                  _fieldsSection(),
                  const SizedBox(height: 24.0),
                  _addButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _imagesSection() {
    return SizedBox(
      width: double.infinity,
      height: 200,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: vehicleImages.isEmpty
            ? InkWell(
                borderRadius: BorderRadius.circular(12.0),
                onTap: _addImage,
                child: CardWidget(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Icon(Icons.image_rounded, size: 60, color: AppColors.lightBlue.withAlpha(150)),
                      const Text("Dodaj zdjęcia swojego pojazdu",
                          style: TextStyle(color: AppColors.lightBlue, fontWeight: FontWeight.w600, fontSize: 16.0))
                    ],
                  ),
                ),
              )
            : PageView.builder(
                controller: _pageController,
                itemCount: vehicleImages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.all(8.0).copyWith(
                      left: index == 0 ? 0 : 8.0,
                      right: index == vehicleImages.length - 1 ? 0 : 8.0,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12.0),
                      onTap: _addImage,
                      child: Ink(
                        decoration: BoxDecoration(
                          color: AppColors.lighterDarkBlue,
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Image.file(
                          File(vehicleImages[index].path),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _fieldsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: CustomTextFormFieldWidget(
                  label: "Marka",
                  hint: "BMW",
                  controller: brandCtrl,
                  validator: _requiredValidator,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomTextFormFieldWidget(
                  label: "Model",
                  hint: "M4",
                  controller: modelCtrl,
                  validator: _requiredValidator,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Flexible(
                child: CustomTextFormFieldWidget(
                  label: "Moc (KM)",
                  hint: "150",
                  controller: horsepowerCtrl,
                  keyboardType: TextInputType.number,
                  validator: _numberValidator,
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: CustomTextFormFieldWidget(
                  label: "Pojemność (cm3)",
                  hint: "1498",
                  controller: capacityCtrl,
                  keyboardType: TextInputType.number,
                  validator: _numberValidator,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CustomTextFormFieldWidget(
            label: "Rok produkcji",
            hint: "2024",
            controller: yearCtrl,
            keyboardType: TextInputType.number,
            validator: _yearValidator,
          ),
          CustomTextFormFieldWidget(
            label: "Kolor",
            hint: "Czarny",
            controller: colorCtrl,
            validator: _requiredValidator,
          ),
          CustomTextFormFieldWidget(
            label: "Rodzaj paliwa",
            hint: "Benzyna, Diesel, Elektryk, Gaz, Hybryda",
            controller: fuelCtrl,
            validator: _requiredValidator,
          ),
          CustomTextFormFieldWidget(
            label: "Skrzynia biegów",
            hint: "Manualna / Automatyczna",
            controller: gearboxCtrl,
            validator: _requiredValidator,
          ),
          CustomTextFormFieldWidget(
            label: "Napęd",
            hint: "Na przednie / tylne koła / 4x4",
            controller: driveCtrl,
            validator: _requiredValidator,
          ),
          CustomTextFormFieldWidget(
            label: "Dodatkowe informacje",
            hint: "Notka od właściciela",
            controller: noteCtrl,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'To pole jest wymagane';
    }
    return null;
  }

  String? _numberValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'To pole jest wymagane';
    }
    if (int.tryParse(value.trim()) == null) {
      return 'Wprowadź poprawną liczbę';
    }
    return null;
  }

  String? _yearValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'To pole jest wymagane';
    }
    final year = int.tryParse(value);
    if (year == null || year < 1900 || year > DateTime.now().year + 1) {
      return 'Wprowadź poprawny rok';
    }
    return null;
  }

  Widget _addButton() {
    return SizedBox(
      width: double.infinity,
      child: FloatingActionButton(
        backgroundColor: AppColors.blue,
        onPressed: isSaving ? null : _onAddVehicle,
        child: isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                "DODAJ",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0, color: Colors.white70),
              ),
      ),
    );
  }

  Future<void> _onAddVehicle() async {
    if (isSaving) return;
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Uzupełnij poprawnie wszystkie pola.")),
      );
      return;
    }

    if (vehicleImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Dodaj przynajmniej jedno zdjęcie.")),
      );
      return;
    }

    try {
      setState(() => isSaving = true);

      final newVehicle = Vehicle(
        id: '',
        brand: brandCtrl.text.trim(),
        model: modelCtrl.text.trim(),
        horsepower: int.tryParse(horsepowerCtrl.text.trim()) ?? 0,
        capacityCm3: int.tryParse(capacityCtrl.text.trim()) ?? 0,
        productionYear: int.tryParse(yearCtrl.text.trim()) ?? 0,
        color: colorCtrl.text.trim(),
        fuelType: fuelCtrl.text.trim(),
        gearbox: gearboxCtrl.text.trim(),
        drive: driveCtrl.text.trim(),
        note: noteCtrl.text.trim(),
        imageUrls: [],
        status: "otwarty",
      );

      await GarageBackend.addVehicle(
        newVehicle,
        vehicleImages.map((x) => File(x.path)).toList(),
      );

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Błąd dodawania pojazdu: $e")));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _addImage() async {
    try {
      final List<XFile> pickedFileList = await _picker.pickMultiImage(imageQuality: 100);
      setState(() {
        vehicleImages.clear();
        vehicleImages.addAll(pickedFileList);
      });
    } catch (e) {
      print("Błąd przy dodawaniu zdjęcia: $e");
    }
  }
}