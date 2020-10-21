
import 'package:flutter/material.dart';
import 'package:todo_app/AppColors.dart';

class HomeChildScreenItem {
  static const KEY_RECORD = 'record';
  static const KEY_PET = 'pet';
  static const KEY_RANKING = 'news';
  static const KEY_SETTINGS = 'settings';

  final String key;
  final String iconPath;
  final Color titleColor;

  const HomeChildScreenItem({
    this.key = '',
    this.iconPath = '',
    this.titleColor = AppColors.TEXT_BLACK_LIGHT,
  });
}