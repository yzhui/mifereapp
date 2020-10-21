
import 'package:todo_app/presentation/App.dart';

class GetTodayUsecase {
  final _dateRepository = dependencies.dateRepository;

  Future<DateTime> invoke() {
    print('#####################################');
    print( _dateRepository.getToday());
    return _dateRepository.getToday();
  }
}