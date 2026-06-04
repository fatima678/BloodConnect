// lib/screens/search_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:blood_donation_app/theme.dart';
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

  List<dynamic> allItems = [];

  final String apiUrl =
      "https://manliness-smugness-qualm.ngrok-free.dev/api/blood-banks";

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

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['success'] == true) {
          setState(() {
            allItems = data['data'] ?? [];
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage =
                data['message'] ?? "Failed to fetch blood banks";
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = "Server Error: ${response.statusCode}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Connection Error: $e";
        isLoading = false;
      });
    }
  }

  List<dynamic> get filteredItems {
    List<dynamic> items = List.from(allItems);

    // Search
    if (_searchQuery.isNotEmpty) {
      items = items.where((item) {
        final hospital =
            (item["hospital_name"] ?? "").toString().toLowerCase();

        final address =
            (item["address"] ?? item["location"] ?? "")
                .toString()
                .toLowerCase();

        return hospital.contains(_searchQuery.toLowerCase()) ||
            address.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Filter
    if (_filterType != "All") {
      items = items.where((item) {
        return _filterType == "Blood Bank";
      }).toList();
    }

    // Sort
    if (_sortBy == "Name") {
      items.sort((a, b) => (a["hospital_name"] ?? "")
          .toString()
          .compareTo(
            (b["hospital_name"] ?? "").toString(),
          ));
    } else if (_sortBy == "Latest") {
      items = items.reversed.toList();
    } else if (_sortBy == "Oldest") {
      items = items.toList();
    }

    return items;
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
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
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
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
          // Search Bar
          Padding(
            padding:
                const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText:
                    "Search blood banks near you...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = "");
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
          ),

          // Filter & Sort Buttons
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showFilterBottomSheet,
                    icon: const Icon(Icons.filter_list),
                    label:
                        Text("Filter ($_filterType)"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryMaroon,
                      side:
                          BorderSide(color: primaryMaroon),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12),
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
                      side:
                          BorderSide(color: primaryMaroon),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Results
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : errorMessage.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding:
                              const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Text(
                                errorMessage,
                                textAlign:
                                    TextAlign.center,
                              ),

                              const SizedBox(height: 20),

                              ElevatedButton(
                                onPressed:
                                    fetchBloodBanks,
                                child:
                                    const Text("Retry"),
                              ),
                            ],
                          ),
                        ),
                      )
                    : filteredItems.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 80,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  "No results found",
                                  style:
                                      TextStyle(fontSize: 18),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 16),
                            itemCount:
                                filteredItems.length,
                            itemBuilder:
                                (context, index) {
                              final item =
                                  filteredItems[index];

                              return Card(
                                margin:
                                    const EdgeInsets.only(
                                        bottom: 12),
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                          12),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        primaryMaroon
                                            .withOpacity(
                                                0.1),
                                    child: const Icon(
                                      Icons.local_hospital,
                                      color: primaryMaroon,
                                    ),
                                  ),

                                  title: Text(
                                    item["hospital_name"] ??
                                        "Blood Bank",
                                    style: const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),

                                  subtitle: Text(
                                    item["address"] ??
                                        item["location"] ??
                                        "No Address",
                                  ),

                                  trailing: const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 18,
                                  ),

                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            PatientBloodBankMapScreen(
                                          selectedBank: {
                                            'name': item[
                                                'hospital_name'],
                                            'location':
                                                item['address'] ??
                                                    item[
                                                        'location'],
                                            'lat': item[
                                                'latitude'],
                                            'lng': item[
                                                'longitude'],
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
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