import 'dart:math';
import '../obd/models.dart';
import '../obd/pids.dart';
import 'dtc.dart';

String f1(double v) => v.toStringAsFixed(1);

String sevText(int s) => s == 3 ? 'СЕРЬЁЗНО' : (s == 2 ? 'ВНИМАНИЕ' : 'ИНФО');

// ---------- пороги параметров ----------

Alarm? evalAlarm(int pid, double v, bool running) {
  int lvl = 0;
  String msg = '';
  void setAlarm(int l, String m) {
    lvl = l;
    msg = m;
  }

  switch (pid) {
    case 0x0C:
      if (v > 6500) {
        setAlarm(2, 'Обороты выше допустимых: переключите передачу');
      } else if (v > 6000) {
        setAlarm(1, 'Обороты близко к пределу');
      }
      break;
    case 0x05:
      if (!running) {
        break;
      }
      if (v >= 108) {
        setAlarm(2, 'Перегрев: остановитесь, дайте остыть, крышку не открывайте');
      } else if (v >= 100) {
        setAlarm(1, 'Температура выше нормы: проверьте вентилятор и уровень ОЖ');
      } else if (v < 70) {
        setAlarm(1, 'Двигатель не прогрет: проверьте термостат и датчик ДТОЖ');
      }
      break;
    case 0x06:
    case 0x07:
      {
        final a = v.abs();
        if (a >= 20) {
          setAlarm(2, 'Коррекция топлива вне нормы: подсос воздуха, ДМРВ, давление топлива, форсунки');
        } else if (a >= 10) {
          setAlarm(1, 'Коррекция топлива растёт: проверьте подсос воздуха и ДМРВ');
        }
      }
      break;
    case 0x42:
      if (running) {
        if (v < 12.5 || v > 15.5) {
          setAlarm(2, 'Генератор заряжает неправильно: ремень, щётки, реле-регулятор');
        } else if (v < 13.2 || v > 14.9) {
          setAlarm(1, 'Напряжение бортсети вне нормы (норма 13.8–14.5 В)');
        }
      } else {
        if (v < 11.8) {
          setAlarm(2, 'Аккумулятор сильно разряжен');
        } else if (v < 12.2) {
          setAlarm(1, 'Аккумулятор разряжен');
        }
      }
      break;
    case 0x04:
      if (v >= 95) {
        setAlarm(2, 'Нагрузка на пределе');
      } else if (v >= 85) {
        setAlarm(1, 'Высокая нагрузка на двигатель');
      }
      break;
    case 0x0B:
      if (running && v >= 70) setAlarm(1, 'Давление во впуске высокое: возможен подсос воздуха');
      break;
    case 0x0F:
      if (v >= 80) {
        setAlarm(2, 'Перегрев воздуха на впуске');
      } else if (v >= 60) {
        setAlarm(1, 'Воздух на впуске горячий');
      }
      break;
    case 0x2F:
      if (v < 5) {
        setAlarm(2, 'Топлива почти нет');
      } else if (v < 12) {
        setAlarm(1, 'Мало топлива');
      }
      break;
  }
  if (lvl == 0) return null;
  return Alarm(lvl, pidName(pid), msg);
}

int levelFor(int pid, double v, bool running) => evalAlarm(pid, v, running)?.level ?? 0;

/// Тревоги по текущим значениям и осциллограмме лямбда-зонда
List<Alarm> alarmsFor(Map<int, double> live, Map<int, List<double>> hist) {
  final running = (live[0x0C] ?? 0) > 400;
  final out = <Alarm>[];
  live.forEach((pid, v) {
    final a = evalAlarm(pid, v, running);
    if (a != null) out.add(a);
  });
  final lam = hist[0x14] ?? const <double>[];
  if (running && lam.length >= 20) {
    final mx = lam.reduce((a, b) => a > b ? a : b);
    final mn = lam.reduce((a, b) => a < b ? a : b);
    if (mx - mn < 0.15) {
      out.add(const Alarm(2, 'Лямбда-зонд 1',
          'Сигнал почти не меняется: зонд залип или нет прогрева. Проверьте проводку и температуру'));
    }
  }
  out.sort((a, b) => b.level.compareTo(a.level));
  return out;
}

/// Ошибки из памяти ЭБУ, которые тоже выводятся тревогой
List<Alarm> dtcAlarms(List<String> stored) {
  final out = <Alarm>[];
  for (final c in stored) {
    final d = DtcDb.lookup(c);
    if (d.severity < 2) continue;
    out.add(Alarm(d.severity - 1, c, '${d.title}. Что делать: ${d.steps.isNotEmpty ? d.steps.first : 'см. карточку ошибки'}'));
  }
  return out;
}

// ---------- что было в момент ошибки ----------

class FaultContext {
  static String _f(double? x) => x == null ? '—' : x.toStringAsFixed(1);

  static List<String> explain(String code, FreezeFrame? ff) {
    if (ff == null) return ['Стоп-кадр не записан: ЭБУ не сохранил условия появления ошибки'];
    final rpm = ff.values[0x0C];
    final load = ff.values[0x04];
    final cool = ff.values[0x05];
    final stft = ff.values[0x06];
    final ltft = ff.values[0x07];
    final map = ff.values[0x0B];
    final tps = ff.values[0x11];
    final r = rpm == null ? '—' : rpm.toInt().toString();
    final out = <String>[];
    if (rpm != null) out.add('Обороты в момент ошибки: ${rpm.toInt()} об/мин');
    if (cool != null) out.add('Температура ОЖ: ${cool.toInt()} °C');
    if (load != null) out.add('Нагрузка: ${load.toInt()} %');

    if (code.startsWith('P030')) {
      final idle = (rpm ?? 0) >= 1 && (rpm ?? 0) <= 1000;
      out.add(idle
          ? 'Пропуски на холостом ходу: чаще всего свеча, катушка или подсос воздуха'
          : (load ?? 0) > 60
              ? 'Пропуски под нагрузкой: проверьте давление топлива и свечи под нагрузкой'
              : 'Пропуски на режиме движения: проверьте свечи, провода и подачу топлива');
    } else if (code == 'P0171' || code == 'P0172') {
      out.add('Коррекция топлива: кратковременная ${_f(stft)} %, долговременная ${_f(ltft)} %');
    } else if (['P0115', 'P0116', 'P0117', 'P0118'].contains(code)) {
      out.add('Датчик ОЖ показывал ${_f(cool)} °C при $r об/мин');
    } else if (['P0335', 'P0336', 'P0337', 'P0338', 'P0339'].contains(code)) {
      out.add('Сигнал ДПКВ пропал или стал неверным при $r об/мин. Если двигатель работал, датчик или задающий диск дают сбой');
    } else if (['P0325', 'P0327', 'P0328'].contains(code)) {
      out.add('Датчик детонации неисправен: ЭБУ не контролирует детонацию при нагрузке ${_f(load)} %');
    } else if (['P0106', 'P0107', 'P0108'].contains(code)) {
      out.add('Давление во впуске ${_f(map)} кПа при $r об/мин');
    } else if (['P0505', 'P0506', 'P0507'].contains(code)) {
      out.add('Ошибка холостого хода: дроссель ${_f(tps)} %, обороты $r');
    } else if (code.startsWith('P013') || code.startsWith('P014')) {
      out.add('Лямбда-зонд не выдавал нормальный сигнал при $r об/мин и ОЖ ${_f(cool)} °C');
    }
    return out;
  }
}

// ---------- покрытие параметров ----------

/// state: 0 - читается, 1 - частично, 2 - стандарт не передаёт, 3 - ошибка
class Coverage {
  final String name;
  final int state;
  final String note;
  const Coverage(this.name, this.state, this.note);
}

List<Coverage> coverageList(Set<int> sup, List<String> stored) {
  final crank = stored.any((c) => ['P0335', 'P0336', 'P0337', 'P0338', 'P0339'].contains(c));
  final knock = stored.any((c) => ['P0325', 'P0327', 'P0328'].contains(c));
  const stdNo = 'Стандарт OBD-II не предусматривает. Нужен оригинальный сканер';
  Coverage cov(String name, int pid, String yes) =>
      sup.contains(pid) ? Coverage(name, 0, yes) : Coverage(name, 2, 'ЭБУ не отдаёт этот параметр');
  return [
    cov('Кратковременная коррекция топлива', 0x06, 'Есть, см. осциллограф'),
    cov('Долговременная коррекция топлива', 0x07, 'Есть, см. осциллограф'),
    cov('Напряжение генератора (бортсеть)', 0x42, 'Есть. При работе двигателя норма 13.8–14.5 В'),
    cov('Расход воздуха (ДМРВ)', 0x10, 'Есть, расход в г/с'),
    cov('Адсорбер: продувка', 0x2E, 'Есть, % открытия клапана продувки'),
    Coverage(
      'Сигнал датчика коленвала',
      crank ? 3 : (sup.contains(0x0C) ? 1 : 2),
      crank
          ? 'ОШИБКА ДПКВ в памяти. См. карточку ошибки'
          : (sup.contains(0x0C) ? 'Видно по оборотам. Прямого сигнала датчика стандарт не даёт' : 'Обороты не получены'),
    ),
    Coverage(
      'Детонация',
      knock ? 3 : 1,
      knock ? 'ОШИБКА датчика детонации в памяти' : 'Уровень детонации стандарт не передаёт. Видны только коды P0325–P0328',
    ),
    const Coverage('Давление кондиционера', 2, stdNo),
    const Coverage('Флаг давления усилителя руля', 2, stdNo),
  ];
}

// ---------- анализ ----------

Analysis analyze({
  required List<String> stored,
  required List<String> pending,
  required List<String> permanent,
  Readiness? readiness,
  required List<Map<int, double>> snaps,
  required List<double> lambda,
  double? adapterVolt,
}) {
  final f = <Finding>[];
  final all = {...stored, ...pending, ...permanent}.toList();
  List<double> vals(int pid) => [for (final s in snaps) if (s[pid] != null) s[pid]!];
  double? avg(List<double> l) => l.isEmpty ? null : l.reduce((a, b) => a + b) / l.length;

  final rpmList = vals(0x0C);
  final rpm = avg(rpmList);
  final running = rpm != null && rpm > 400;
  final speed = avg(vals(0x0D));
  final cl = vals(0x05);
  final coolant = avg(cl.length > 5 ? cl.sublist(cl.length - 5) : cl);
  final rt = vals(0x1F);
  final runtime = rt.isEmpty ? null : rt.last;
  final idle = running && (speed == null || speed < 2.0);
  final warm = coolant != null && coolant >= 75.0;

  if (snaps.isEmpty) {
    f.add(const Finding(1, 'Живые данные не получены',
        'ЭБУ не отдал значения датчиков по OBD-II. Возможно, выключено зажигание или блок не поддерживает эти параметры.',
        ['Включите зажигание и повторите проверку']));
  } else if (!running) {
    f.add(const Finding(1, 'Двигатель не работал во время проверки',
        'Анализ коррекций, холостого хода и лямбда-зонда возможен только на работающем двигателе.',
        ['Заведите двигатель, прогрейте до 80 °C и повторите диагностику']));
  }

  if (stored.isNotEmpty) {
    final sev = stored.map((c) => DtcDb.lookup(c).severity).reduce((a, b) => a > b ? a : b);
    f.add(Finding(sev, 'Сохранённые ошибки: ${stored.length}', stored.join(', '),
        ['Подробные причины и рекомендации по каждому коду ниже', 'Сначала устраните причину, потом сбрасывайте ошибки']));
  }
  if (pending.isNotEmpty) {
    f.add(Finding(1, 'Ожидающие ошибки: ${pending.length}',
        '${pending.join(', ')}. Это неподтверждённые сбои: лампа ещё не горит.', ['Проверьте указанные узлы заранее']));
  }
  if (readiness != null && readiness.milOn && stored.isEmpty) {
    f.add(const Finding(2, 'Лампа Check Engine горит, но сохранённых кодов нет',
        'Код может относиться к системе, недоступной по OBD-II, или ошибки уже сброшены.',
        ['Проверьте родным протоколом ВАЗ или оригинальным сканером']));
  }

  if (coolant != null && running) {
    final mx = cl.isEmpty ? coolant : cl.reduce((a, b) => a > b ? a : b);
    if (mx >= 108) {
      f.add(Finding(3, 'Перегрев двигателя', 'Температура ОЖ до ${f1(mx)} °C.',
          ['Остановите двигатель, дайте остыть, крышку бачка не открывайте на горячем', 'Проверьте уровень ОЖ, вентилятор, термостат, радиатор']));
    } else if (mx >= 100) {
      f.add(Finding(2, 'Повышенная температура двигателя', 'Температура ОЖ достигала ${f1(mx)} °C.',
          ['Проверьте включение вентилятора (около 99–104 °C)', 'Проверьте уровень ОЖ и чистоту радиатора']));
    } else if (coolant < 75 && runtime != null && runtime > 600) {
      f.add(Finding(2, 'Двигатель не прогревается', 'Через ${(runtime / 60).toInt()} мин работы температура ${f1(coolant)} °C.',
          ['Проверьте термостат (открывается около 87 °C)', 'Сравните показания ДТОЖ с температурой патрубков']));
    }
  }

  final stft = avg(vals(0x06));
  final ltft = avg(vals(0x07));
  if (running && warm && (stft != null || ltft != null)) {
    final total = (stft ?? 0) + (ltft ?? 0);
    final txt = 'Коррекции: кратковременная ${stft == null ? '—' : f1(stft)} %, долговременная ${ltft == null ? '—' : f1(ltft)} %.';
    if (total > 12) {
      f.add(Finding(total > 25 ? 3 : 2, 'Смесь бедная (ЭБУ добавляет топливо)',
          txt + (all.contains('P0171') ? ' Совпадает с кодом P0171.' : ''),
          ['Проверьте подсос воздуха: гофра ДМРВ, шланги, прокладка коллектора, вакуумный усилитель',
            'Проверьте давление топлива и фильтр', 'Проверьте и очистите ДМРВ', 'Проверьте форсунки на засорение']));
    } else if (total < -12) {
      f.add(Finding(total < -25 ? 3 : 2, 'Смесь богатая (ЭБУ убирает топливо)',
          txt + (all.contains('P0172') ? ' Совпадает с кодом P0172.' : ''),
          ['Проверьте давление топлива (регулятор) и подтекание форсунок', 'Проверьте воздушный фильтр',
            'Проверьте клапан продувки адсорбера', 'Проверьте ДТОЖ и ДМРВ']));
    }
  }

  final vl = avg(vals(0x42)) ?? adapterVolt;
  if (vl != null) {
    if (running) {
      if (vl < 13.2) {
        f.add(Finding(2, 'Низкое напряжение бортсети: ${f1(vl)} В',
            'При работе двигателя должно быть 13.8–14.5 В. Аккумулятор разряжается.',
            ['Проверьте ремень генератора и его натяжение', 'Проверьте щётки, реле-регулятор и контакты генератора', 'Проверьте клеммы АКБ и массы']));
      } else if (vl > 14.9) {
        f.add(Finding(vl > 15.5 ? 3 : 2, 'Повышенное напряжение: ${f1(vl)} В',
            'Выше 15 В электроника и аккумулятор перегружаются.',
            ['Проверьте реле-регулятор генератора', 'Проверьте массу двигателя и клеммы АКБ']));
      }
    } else if (vl < 11.8) {
      f.add(Finding(2, 'Низкое напряжение аккумулятора: ${f1(vl)} В', 'Аккумулятор сильно разряжен или изношен.',
          ['Зарядите аккумулятор и проверьте нагрузочной вилкой', 'Проверьте утечки тока']));
    }
  }

  if (idle && warm && rpm != null) {
    var sd = 0.0;
    if (rpmList.length > 1) {
      final v = rpmList.map((x) => (x - rpm) * (x - rpm)).reduce((a, b) => a + b) / rpmList.length;
      sd = sqrt(v);
    }
    if (rpm > 1000) {
      f.add(Finding(2, 'Повышенные обороты холостого хода: ${rpm.toInt()} об/мин',
          'Для прогретого 1.5 л 8 кл. обычно 750–900 об/мин.',
          ['Проверьте подсос воздуха', 'Проверьте дроссель и тросик газа', 'Проверьте РХХ и ДПДЗ']));
    } else if (rpm < 650) {
      f.add(Finding(2, 'Пониженные обороты холостого хода: ${rpm.toInt()} об/мин', 'Двигатель может глохнуть.',
          ['Почистите дроссельный узел и канал РХХ', 'Проверьте давление топлива, свечи и зажигание']));
    }
    if (sd > 60) {
      f.add(Finding(2, 'Плавающие обороты холостого хода', 'Отклонение около ${sd.toInt()} об/мин вокруг ${rpm.toInt()}.',
          ['Проверьте подсос воздуха и РХХ', 'Проверьте свечи, провода и форсунки на пропуски', 'Почистите дроссель']));
    }
  }

  final maf = avg(vals(0x10));
  if (idle && warm && maf != null && (maf < 1.5 || maf > 4.5)) {
    f.add(Finding(2, 'Расход воздуха на холостом нетипичный: ${f1(maf)} г/с',
        'Для 1.5 л на прогретом холостом обычно около 2–3.5 г/с.',
        ['Очистите или проверьте ДМРВ', 'Проверьте подсос воздуха и состояние воздушного фильтра', 'Проверьте дроссель и РХХ']));
  }

  final tps = avg(vals(0x11));
  if (idle && tps != null && tps > 5) {
    f.add(Finding(2, 'Дроссель на холостом приоткрыт: ${f1(tps)} %', 'Заслонка должна быть закрыта (около 0–2 %).',
        ['Проверьте тросик и педаль газа', 'Почистите дроссельный узел', 'Проверьте ДПДЗ']));
  }

  if (running && warm && lambda.length >= 15) {
    final mn = lambda.reduce((a, b) => a < b ? a : b);
    final mx = lambda.reduce((a, b) => a > b ? a : b);
    final mean = lambda.reduce((a, b) => a + b) / lambda.length;
    var crossings = 0;
    for (var i = 1; i < lambda.length; i++) {
      if ((lambda[i - 1] - 0.45) * (lambda[i] - 0.45) < 0) crossings++;
    }
    if (mx - mn < 0.25) {
      final state = mean > 0.6 ? 'залип на богатой смеси' : (mean < 0.3 ? 'залип на бедной смеси' : 'почти не колеблется');
      f.add(Finding(2, 'Лямбда-зонд 1: сигнал $state', 'Размах сигнала ${f1(mx - mn)} В (у исправного зонда 0.1–0.9 В).',
          ['Проверьте проводку и колодку зонда', 'Проверьте подсос воздуха и давление топлива', 'Замените зонд, если он старше 80–100 тыс. км']));
    } else if (crossings < 6) {
      f.add(Finding(1, 'Лямбда-зонд 1: вялая реакция (возможно)', 'Сигнал пересёк средний уровень $crossings раз за проверку.',
          ['Повторите замер при другой нагрузке', 'При подтверждении замените зонд']));
    }
  }

  if (readiness != null) {
    final inc = readiness.items.where((i) => !i.complete).toList();
    if (inc.isNotEmpty) {
      f.add(Finding(1, 'Тесты готовности не завершены: ${inc.length}',
          '${inc.map((e) => e.name).join(', ')}. Обычно так бывает после сброса ошибок или отключения АКБ.',
          ['Проедьте несколько циклов прогрева и движения, затем проверьте снова']));
    }
  }

  if (all.any((c) => c == 'P0115' || c == 'P0117' || c == 'P0118') &&
      coolant != null && (coolant <= -35 || coolant >= 130)) {
    f.add(Finding(2, 'Показания ДТОЖ подтверждают неисправность датчика', 'Датчик показывает ${f1(coolant)} °C, что нереально.',
        ['Проверьте провода и колодку ДТОЖ', 'Замените датчик']));
  }

  var score = 100;
  for (final x in f) {
    score -= x.severity == 3 ? 25 : (x.severity == 2 ? 10 : 2);
  }
  for (final c in stored) {
    score -= DtcDb.lookup(c).severity >= 3 ? 15 : 8;
  }
  score = score < 0 ? 0 : (score > 100 ? 100 : score);
  final verdict = score >= 85 ? 'Хорошее состояние' : (score >= 60 ? 'Есть замечания' : 'Требуется ремонт');
  f.sort((a, b) => b.severity.compareTo(a.severity));
  return Analysis(score, verdict, f);
}
