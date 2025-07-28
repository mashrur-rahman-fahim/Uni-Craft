import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import '../services/study_material_service.dart';

class UploadFile extends StatefulWidget {
  final String groupCode;

  const UploadFile({Key? key, required this.groupCode}) : super(key: key);

  @override
  State<UploadFile> createState() => _UploadFileState();
}

class _UploadFileState extends State<UploadFile> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final StudyMaterialService _materialService = StudyMaterialService();

  File? _selectedFile;
  String? _fileName;
  int? _fileSize;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadType = 'file'; // 'file' or 'link'

  @override
  void dispose() {
    _descriptionController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffb8d8d8),
      appBar: AppBar(
        title: const Text(
          "Upload Material",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xff7a9e9f),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUploadTypeSelector(),
            const SizedBox(height: 24),
            if (_uploadType == 'file') ...[
              _buildFileUploadSection(),
            ] else ...[
              _buildLinkUploadSection(),
            ],
            const SizedBox(height: 24),
            _buildDescriptionSection(),
            const SizedBox(height: 32),
            _buildUploadButton(),
            if (_isUploading) ...[
              const SizedBox(height: 20),
              _buildProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUploadTypeSelector() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Upload Type",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xff7a9e9f),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTypeOption(
                    'file',
                    'File Upload',
                    Icons.file_upload,
                    'Upload documents, images, videos',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTypeOption(
                    'link',
                    'Share Link',
                    Icons.link,
                    'Share external links or URLs',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption(String type, String title, IconData icon, String subtitle) {
    final isSelected = _uploadType == type;
    return GestureDetector(
      onTap: () => setState(() => _uploadType = type),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xff7a9e9f).withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xff7a9e9f) : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? const Color(0xff7a9e9f) : Colors.grey[600],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xff7a9e9f) : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileUploadSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select File",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xff7a9e9f),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _isUploading ? null : _pickFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _selectedFile != null
                      ? const Color(0xff7a9e9f).withOpacity(0.1)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _selectedFile != null
                        ? const Color(0xff7a9e9f)
                        : Colors.grey[300]!,
                    style: BorderStyle.solid,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _selectedFile != null ? Icons.check_circle : Icons.cloud_upload,
                      size: 48,
                      color: _selectedFile != null
                          ? Colors.green
                          : const Color(0xff7a9e9f),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _selectedFile != null
                          ? _fileName ?? 'File selected'
                          : 'Tap to select a file',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _selectedFile != null
                            ? Colors.green[700]
                            : const Color(0xff7a9e9f),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_selectedFile != null && _fileSize != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatFileSize(_fileSize!),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    if (_selectedFile == null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Supports: Images, Documents, Videos, Audio',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkUploadSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Share Link",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xff7a9e9f),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _linkController,
              decoration: InputDecoration(
                hintText: 'Enter URL (e.g., https://example.com)',
                prefixIcon: const Icon(Icons.link, color: Color(0xff7a9e9f)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xff7a9e9f), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              keyboardType: TextInputType.url,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Description (Optional)",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xff7a9e9f),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                hintText: 'Add a description for this material...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xff7a9e9f), width: 2),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              maxLines: 3,
              maxLength: 200,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadButton() {
    final bool canUpload = _uploadType == 'file'
        ? _selectedFile != null
        : _linkController.text.trim().isNotEmpty;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: canUpload && !_isUploading ? _uploadMaterial : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xff7a9e9f),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: canUpload ? 4 : 0,
        ),
        child: _isUploading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Uploading...'),
                ],
              )
            : Text(
                _uploadType == 'file' ? 'Upload File' : 'Share Link',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Upload Progress',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${(_uploadProgress * 100).toInt()}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xff7a9e9f),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xff7a9e9f)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        setState(() {
          _selectedFile = file;
          _fileName = result.files.first.name;
          _fileSize = result.files.first.size;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error selecting file: $e');
    }
  }

  Future<void> _uploadMaterial() async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      if (_uploadType == 'file' && _selectedFile != null) {
        await _uploadFileToStorage();
      } else if (_uploadType == 'link') {
        await _saveLink();
      }
    } catch (e) {
      _showErrorSnackBar('Upload failed: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadFileToStorage() async {
    if (_selectedFile == null || _fileName == null) return;

    try {
      // Create storage reference
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _fileName!.split('.').last;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('study_materials')
          .child(widget.groupCode)
          .child('${timestamp}_$_fileName');

      // Start upload
      final uploadTask = storageRef.putFile(_selectedFile!);

      // Monitor progress
      uploadTask.snapshotEvents.listen((snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      // Wait for completion
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Save to Firestore
      final fileType = StudyMaterialService.getFileType(_fileName!);
      final success = await _materialService.addStudyMaterial(
        groupCode: widget.groupCode,
        name: _fileName!,
        url: downloadUrl,
        type: fileType,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        fileSize: _fileSize,
      );

      if (success) {
        _showSuccessSnackBar('File uploaded successfully!');
        Navigator.pop(context, true);
      } else {
        throw Exception('Failed to save file information');
      }
    } catch (e) {
      print('Upload error: $e');
      throw e;
    }
  }

  Future<void> _saveLink() async {
    final link = _linkController.text.trim();
    if (link.isEmpty) return;

    try {
      setState(() => _uploadProgress = 0.5);

      final success = await _materialService.addStudyMaterial(
        groupCode: widget.groupCode,
        name: link,
        url: link,
        type: 'link',
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      setState(() => _uploadProgress = 1.0);

      if (success) {
        _showSuccessSnackBar('Link shared successfully!');
        Navigator.pop(context, true);
      } else {
        throw Exception('Failed to save link');
      }
    } catch (e) {
      throw e;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
