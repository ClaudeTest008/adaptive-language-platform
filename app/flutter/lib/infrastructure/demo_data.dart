/// Seeded demo content: one driver's license exam, 4 topics, 24 questions.
/// Replaced by Firestore content once Epic 4 deploy completes.
library;

import '../domain/models.dart';

const demoExam = Exam(
  id: 'us-drivers-license',
  name: "Driver's License — Demo",
  questionCount: 10,
  passThreshold: 8,
  timeLimitMinutes: 15,
);

const demoTopics = [
  Topic(id: 'signs', name: 'Road Signs', order: 1),
  Topic(id: 'right-of-way', name: 'Right of Way', order: 2),
  Topic(id: 'speed-safety', name: 'Speed & Safety', order: 3),
  Topic(id: 'parking-rules', name: 'Parking & Rules', order: 4),
];

const _e = 'us-drivers-license';

const demoQuestions = [
  // ---- Road Signs ----
  Question(
    id: 'q01',
    examId: _e,
    topicId: 'signs',
    text: 'An eight-sided red sign means:',
    answers: [
      'Yield to traffic',
      'Come to a complete stop',
      'Slow down',
      'No entry',
    ],
    correctIndex: 1,
    explanation:
        'The octagon shape is reserved for STOP signs. You must come to a complete stop at the stop line, crosswalk, or intersection edge.',
  ),
  Question(
    id: 'q02',
    examId: _e,
    topicId: 'signs',
    text: 'A triangular sign pointing downward means:',
    answers: ['Stop', 'Yield', 'Merge', 'School zone'],
    correctIndex: 1,
    explanation:
        'The inverted triangle is the YIELD sign: slow down and give the right of way to traffic and pedestrians.',
  ),
  Question(
    id: 'q03',
    examId: _e,
    topicId: 'signs',
    text: 'Diamond-shaped yellow signs are used for:',
    answers: ['Regulations', 'Warnings', 'Services', 'Route numbers'],
    correctIndex: 1,
    explanation:
        'Yellow diamond signs warn of hazards or changes in road conditions ahead, such as curves, intersections, or animal crossings.',
  ),
  Question(
    id: 'q04',
    examId: _e,
    topicId: 'signs',
    text: 'A round sign with a black X and RR letters warns of:',
    answers: [
      'Road repairs',
      'Railroad crossing',
      'Rest area',
      'Reduced lanes',
    ],
    correctIndex: 1,
    explanation:
        'The round yellow advance-warning sign with an X and RR marks an upcoming railroad crossing. Slow down and be ready to stop.',
  ),
  Question(
    id: 'q05',
    examId: _e,
    topicId: 'signs',
    text: 'Orange signs on the road indicate:',
    answers: [
      'School zones',
      'Construction and work zones',
      'Hospital zones',
      'No passing zones',
    ],
    correctIndex: 1,
    explanation:
        'Orange is reserved for temporary traffic control in construction and maintenance work zones. Fines are often doubled there.',
  ),
  Question(
    id: 'q06',
    examId: _e,
    topicId: 'signs',
    text: 'A pentagon-shaped sign indicates:',
    answers: [
      'Hospital ahead',
      'School zone or crossing',
      'Railroad crossing',
      'Dead end',
    ],
    correctIndex: 1,
    explanation:
        'The five-sided pentagon shape is used only for school zone and school crossing signs. Watch for children and reduce speed.',
  ),
  // ---- Right of Way ----
  Question(
    id: 'q07',
    examId: _e,
    topicId: 'right-of-way',
    text:
        'At a four-way stop, two vehicles arrive at the same time. Who goes first?',
    answers: [
      'The vehicle on the left',
      'The vehicle on the right',
      'The larger vehicle',
      'Whoever moves first',
    ],
    correctIndex: 1,
    explanation:
        'When two vehicles reach a four-way stop simultaneously, the driver on the left yields to the driver on the right.',
  ),
  Question(
    id: 'q08',
    examId: _e,
    topicId: 'right-of-way',
    text: 'When turning left at an intersection, you must yield to:',
    answers: [
      'No one if you have a green light',
      'Oncoming traffic going straight',
      'Vehicles behind you',
      'Traffic on your right only',
    ],
    correctIndex: 1,
    explanation:
        'A left turn crosses the path of oncoming traffic. Even on a green light, you must yield to oncoming vehicles going straight or turning right.',
  ),
  Question(
    id: 'q09',
    examId: _e,
    topicId: 'right-of-way',
    text: 'A pedestrian is crossing at an unmarked crosswalk. You should:',
    answers: [
      'Honk to warn them',
      'Yield — pedestrians have the right of way',
      'Proceed if you are faster',
      'Flash your lights and continue',
    ],
    correctIndex: 1,
    explanation:
        'Pedestrians have the right of way at both marked and unmarked crosswalks. You must slow down or stop to let them cross safely.',
  ),
  Question(
    id: 'q10',
    examId: _e,
    topicId: 'right-of-way',
    text: 'An emergency vehicle approaches with lights and siren on. You must:',
    answers: [
      'Speed up to clear the road',
      'Pull over to the right edge and stop',
      'Stop exactly where you are',
      'Change lanes to the left',
    ],
    correctIndex: 1,
    explanation:
        'Pull as close as possible to the right edge of the road and stop until the emergency vehicle has passed — unless you are in an intersection, then clear it first.',
  ),
  Question(
    id: 'q11',
    examId: _e,
    topicId: 'right-of-way',
    text: 'When entering a highway from an on-ramp, you should:',
    answers: [
      'Stop and wait for a gap',
      'Adjust speed to match traffic and merge into a gap',
      'Enter slowly — traffic must let you in',
      'Use the shoulder until a gap appears',
    ],
    correctIndex: 1,
    explanation:
        'Traffic already on the highway has the right of way. Use the acceleration lane to match its speed and merge smoothly into a safe gap.',
  ),
  Question(
    id: 'q12',
    examId: _e,
    topicId: 'right-of-way',
    text: 'At a roundabout, you must yield to:',
    answers: [
      'Traffic entering the roundabout',
      'Traffic already circulating in the roundabout',
      'Traffic on your right',
      'No one — first come, first served',
    ],
    correctIndex: 1,
    explanation:
        'Vehicles already inside the roundabout have priority. Yield before entering, then proceed counterclockwise to your exit.',
  ),
  // ---- Speed & Safety ----
  Question(
    id: 'q13',
    examId: _e,
    topicId: 'speed-safety',
    text: 'The three-second rule helps you maintain:',
    answers: [
      'Proper engine temperature',
      'A safe following distance',
      'Correct lane position',
      'Legal speed',
    ],
    correctIndex: 1,
    explanation:
        'Pick a fixed object; when the car ahead passes it, count three seconds. Reaching the object sooner means you are following too closely. Increase to 4+ seconds in bad weather.',
  ),
  Question(
    id: 'q14',
    examId: _e,
    topicId: 'speed-safety',
    text: 'You should reduce speed below the posted limit when:',
    answers: [
      'Never — the limit always applies',
      'Road, weather, or traffic conditions are poor',
      'Only when signs say so',
      'Only at night',
    ],
    correctIndex: 1,
    explanation:
        'The posted limit applies to ideal conditions. The basic speed law requires driving no faster than is safe for current conditions — rain, fog, ice, or heavy traffic demand less speed.',
  ),
  Question(
    id: 'q15',
    examId: _e,
    topicId: 'speed-safety',
    text: 'Your vehicle starts to skid on a wet road. You should:',
    answers: [
      'Brake hard immediately',
      'Ease off the accelerator and steer in the direction you want to go',
      'Turn the wheel opposite to the skid and accelerate',
      'Pull the handbrake',
    ],
    correctIndex: 1,
    explanation:
        'Hard braking worsens a skid. Ease off the gas and steer smoothly toward where you want the car to go until traction returns.',
  ),
  Question(
    id: 'q16',
    examId: _e,
    topicId: 'speed-safety',
    text: 'Hydroplaning is most likely when:',
    answers: [
      'Driving slowly in rain',
      'Driving fast on standing water',
      'Braking on dry pavement',
      'Driving uphill',
    ],
    correctIndex: 1,
    explanation:
        'At higher speeds tires cannot channel water away and ride on top of it, losing road contact. Slow down in rain, especially through puddles.',
  ),
  Question(
    id: 'q17',
    examId: _e,
    topicId: 'speed-safety',
    text: 'At night, dim your high beams when:',
    answers: [
      'Another vehicle is within about 500 feet',
      'Only when it rains',
      'Driving over 50 mph',
      'Never — high beams are always safer',
    ],
    correctIndex: 0,
    explanation:
        'Dim high beams within roughly 500 ft of oncoming vehicles (and when following closely) to avoid blinding other drivers.',
  ),
  Question(
    id: 'q18',
    examId: _e,
    topicId: 'speed-safety',
    text: 'The main effect of alcohol on driving is:',
    answers: [
      'Improved focus at low doses',
      'Slowed reaction time and impaired judgment',
      'Better night vision',
      'No effect below the legal limit',
    ],
    correctIndex: 1,
    explanation:
        'Alcohol impairs judgment, coordination, and reaction time starting with the first drink — well before the legal limit. The only safe amount when driving is none.',
  ),
  // ---- Parking & Rules ----
  Question(
    id: 'q19',
    examId: _e,
    topicId: 'parking-rules',
    text: 'When parking downhill with a curb, turn your front wheels:',
    answers: [
      'Away from the curb',
      'Toward the curb',
      'Straight ahead',
      'It does not matter',
    ],
    correctIndex: 1,
    explanation:
        'Downhill: turn wheels toward the curb so the car rolls into it if brakes fail. Uphill with a curb: turn wheels away from the curb.',
  ),
  Question(
    id: 'q20',
    examId: _e,
    topicId: 'parking-rules',
    text: 'Parking is prohibited within what distance of a fire hydrant?',
    answers: ['5 feet', '15 feet', '30 feet', '50 feet'],
    correctIndex: 1,
    explanation:
        'Most jurisdictions prohibit parking within 15 feet of a fire hydrant so fire crews have unobstructed access.',
  ),
  Question(
    id: 'q21',
    examId: _e,
    topicId: 'parking-rules',
    text: 'A solid yellow line on your side of the center line means:',
    answers: [
      'Passing is allowed with care',
      'No passing',
      'Two-way traffic ends',
      'Shoulder driving permitted',
    ],
    correctIndex: 1,
    explanation:
        'A solid yellow line on your side means passing is prohibited. A broken yellow line on your side would permit passing when safe.',
  ),
  Question(
    id: 'q22',
    examId: _e,
    topicId: 'parking-rules',
    text: 'A school bus stops ahead with red lights flashing. You must:',
    answers: [
      'Pass slowly on the left',
      'Stop, regardless of your direction, until lights stop flashing',
      'Stop only if children are visible',
      'Honk and proceed',
    ],
    correctIndex: 1,
    explanation:
        'Flashing red lights on a school bus require traffic in both directions to stop (except on divided highways for oncoming traffic, where rules vary). Wait until the lights stop.',
  ),
  Question(
    id: 'q23',
    examId: _e,
    topicId: 'parking-rules',
    text:
        'You approach an intersection with a non-working traffic light. Treat it as:',
    answers: [
      'A yield sign',
      'A four-way stop',
      'A green light',
      'A pedestrian zone',
    ],
    correctIndex: 1,
    explanation:
        'A dark or malfunctioning signal is treated as an all-way stop: stop completely, then proceed using four-way-stop right-of-way rules.',
  ),
  Question(
    id: 'q24',
    examId: _e,
    topicId: 'parking-rules',
    text: 'Using a handheld phone while driving is:',
    answers: [
      'Allowed under 25 mph',
      'Prohibited — use hands-free or pull over',
      'Allowed at red lights only',
      'Allowed for navigation',
    ],
    correctIndex: 1,
    explanation:
        'Handheld phone use while driving is illegal in most jurisdictions and a leading cause of distracted-driving crashes. Use hands-free systems or stop safely first.',
  ),
];
