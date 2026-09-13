import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repos/address_repo.dart';
import '../logic/address_cubit.dart';
import 'add_address_bottom_sheet.dart';

class AddressesScreen extends StatelessWidget {
  final bool isPickerMode;

  const AddressesScreen({super.key, this.isPickerMode = false});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AddressCubit(AddressRepo())..fetchAddresses(),
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: Text(isPickerMode ? 'اختر عنوان التوصيل' : 'عناويني'),
              backgroundColor: const Color(0xFF000826),
              foregroundColor: Colors.white,
            ),
            floatingActionButton: FloatingActionButton.extended(
              backgroundColor: const Color(0xFF007BFF),
              onPressed: () {
                final cubit = context.read<AddressCubit>();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => BlocProvider.value(
                    value: cubit,
                    child: const AddAddressBottomSheet(),
                  ),
                );
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('إضافة عنوان', style: TextStyle(color: Colors.white)),
            ),
            body: BlocConsumer<AddressCubit, AddressState>(
              listener: (context, state) {
                if (state is AddressActionSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.message), backgroundColor: Colors.green),
                  );
                } else if (state is AddressError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.error), backgroundColor: Colors.red),
                  );
                }
              },
              builder: (context, state) {
                if (state is AddressLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is AddressLoaded) {
                  if (state.addresses.isEmpty) {
                    return const Center(child: Text('لا توجد عناوين محفوظة'));
                  }
                  return ListView.builder(
                    itemCount: state.addresses.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final address = state.addresses[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                        child: ListTile(
                          onTap: isPickerMode ? () => Navigator.pop(context, address) : null,
                          title: Row(
                            children: [
                              Text(address.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              if (address.isDefault)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                                  child: const Text('افتراضي', style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(address.fullAddressText),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!address.isDefault)
                                IconButton(
                                  icon: const Icon(Icons.star_border, color: Colors.grey),
                                  tooltip: 'تعيين كافتراضي',
                                  onPressed: () => context.read<AddressCubit>().setDefaultAddress(address.id),
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => context.read<AddressCubit>().deleteAddress(address.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          );
        },
      ),
    );
  }
}