// lib/screens/search_screen.dart

import 'package:flutter/material.dart';

import 'package:blood_donation_app/theme.dart';
import 'package:blood_donation_app/sdk/core/sdk_exception.dart';
import 'package:blood_donation_app/sdk/patient/patient_search_sdk.dart';

import 'patient_blood_bank_map_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = "";
  String _sortBy = "Latest";
  String _filterType = "All";

  bool isLoading = true;
  String errorMessage = '';

  List<Map<String, dynamic>> allItems = [];

  @override
  void initState() {
    super.initState();
    fetchBloodBanks();
  }

  Future<void> fetchBloodBanks() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      final List<Map<String, dynamic>> banks =
          await PatientSearchSdk.fetchBloodBanksForSearch(
        limit: 100,
      );

      if (!mounted) return;

      setState(() {
        allItems = banks;
        isLoading = false;
        errorMessage = '';
      });
    } on SdkException catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.message;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = "Error: $e";
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get filteredItems {
    List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(allItems);

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();

      items = items.where((item) {
        final hospital =
            (item["hospital_name"] ?? item["name"] ?? "")
                .toString()
                .toLowerCase();

        final address =
            (item["address"] ?? item["location"] ?? "")
                .toString()
                .toLowerCase();

        final phone =
            (item["phone_number"] ?? item["phone"] ?? "")
                .toString()
                .toLowerCase();

        return hospital.contains(query) ||
            address.contains(query) ||
            phone.contains(query);
      }).toList();
    }

    if (_filterType != "All") {
      items = items.where((item) {
        return _filterType == "Blood Bank";
      }).toList();
    }

    if (_sortBy == "Name") {
      items.sort((a, b) {
        final aName = (a["hospital_name"] ?? a["name"] ?? "").toString();
        final bName = (b["hospital_name"] ?? b["name"] ?? "").toString();

        return aName.compareTo(bName);
      });
    } else if (_sortBy == "Latest") {
      items.sort((a, b) {
        final bTime =
            (b['created_at'] ?? b['updated_at'] ?? '').toString();
        final aTime =
            (a['created_at'] ?? a['updated_at'] ?? '').toString();

        return bTime.compareTo(aTime);
      });
    } else if (_sortBy == "Oldest") {
      items.sort((a, b) {
        final aTime =
            (a['created_at'] ?? a['updated_at'] ?? '').toString();
        final bTime =
            (b['created_at'] ?? b['updated_at'] ?? '').toString();

        return aTime.compareTo(bTime);
      });
    }

    return items;
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Sort By",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                title: const Text("Latest"),
                trailing: _sortBy == "Latest"
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  setState(() => _sortBy = "Latest");
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text("Oldest"),
                trailing: _sortBy == "Oldest"
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  setState(() => _sortBy = "Oldest");
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text("Name (A-Z)"),
                trailing: _sortBy == "Name"
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  setState(() => _sortBy = "Name");
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Filter By Type",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                title: const Text("All"),
                trailing: _filterType == "All"
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  setState(() => _filterType = "All");
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text("Blood Bank"),
                trailing: _filterType == "Blood Bank"
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  setState(() => _filterType = "Blood Bank");
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void openBloodBankMap(Map<String, dynamic> item) {
    final double? latitude = item['latitude'] is num
        ? (item['latitude'] as num).toDouble()
        : double.tryParse(item['latitude']?.toString() ?? '');

    final double? longitude = item['longitude'] is num
        ? (item['longitude'] as num).toDouble()
        : double.tryParse(item['longitude']?.toString() ?? '');

    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Blood bank location is not available.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientBloodBankMapScreen(
          selectedBank: {
            'name': item['hospital_name'] ?? item['name'] ?? 'Blood Bank',
            'location': item['address'] ?? item['location'] ?? 'No Address',
            'lat': latitude,
            'lng': longitude,
          },
        ),
      ),
    );
  }

  Widget buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: "Search blood banks near you...",
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();

                    setState(() {
                      _searchQuery = "";
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
      ),
    );
  }

  Widget buildFilterSortButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showFilterBottomSheet,
              icon: const Icon(Icons.filter_list),
              label: Text("Filter ($_filterType)"),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryMaroon,
                side: const BorderSide(color: primaryMaroon),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showSortBottomSheet,
              icon: const Icon(Icons.sort),
              label: Text("Sort ($_sortBy)"),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryMaroon,
                side: const BorderSide(color: primaryMaroon),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: fetchBloodBanks,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryMaroon,
              ),
              child: const Text(
                "Retry",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            "No results found",
            style: TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget buildBloodBankCard(Map<String, dynamic> item) {
    final hospitalName =
        item["hospital_name"] ?? item["name"] ?? "Blood Bank";

    final address =
        item["address"] ?? item["location"] ?? "No Address";

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: primaryMaroon.withOpacity(0.1),
          child: const Icon(
            Icons.local_hospital,
            color: primaryMaroon,
          ),
        ),
        title: Text(
          hospitalName.toString(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(address.toString()),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 18,
        ),
        onTap: () => openBloodBankMap(item),
      ),
    );
  }

  Widget buildResultList() {
    final items = filteredItems;

    if (items.isEmpty) {
      return buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: fetchBloodBanks,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];

          return buildBloodBankCard(item);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Search"),
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: fetchBloodBanks,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          buildSearchBar(),
          buildFilterSortButtons(),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : errorMessage.isNotEmpty
                    ? buildErrorState()
                    : buildResultList(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}