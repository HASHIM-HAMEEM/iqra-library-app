const { createClient } = require('@supabase/supabase-js');
const { randomUUID } = require('crypto');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_ANON_KEY;
const testEmail = process.env.TEST_EMAIL;
const testPassword = process.env.TEST_PASSWORD;

if (!supabaseUrl || !supabaseKey || !testEmail || !testPassword) {
  console.error('Missing required environment variables');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

// Dummy student data
const dummyStudents = [
  {
    id: 'student_001',
    first_name: 'Ahmed',
    last_name: 'Hassan',
    email: 'ahmed.hassan@example.com',
    phone: '+1234567890',
    address: '123 Main Street, City, State 12345',
    date_of_birth: '1995-03-15T00:00:00Z',
    seat_number: 'A001'
  },
  {
    id: 'student_002',
    first_name: 'Fatima',
    last_name: 'Al-Zahra',
    email: 'fatima.alzahra@example.com',
    phone: '+1234567892',
    address: '456 Oak Avenue, City, State 12346',
    date_of_birth: '1998-07-22T00:00:00Z',
    seat_number: 'A002'
  },
  {
    id: 'student_003',
    first_name: 'Omar',
    last_name: 'Abdullah',
    email: 'omar.abdullah@example.com',
    phone: '+1234567894',
    address: '789 Pine Road, City, State 12347',
    date_of_birth: '1992-11-08T00:00:00Z',
    seat_number: 'A003'
  },
  {
    id: 'student_004',
    first_name: 'Aisha',
    last_name: 'Mohamed',
    email: 'aisha.mohamed@example.com',
    phone: '+1234567896',
    address: '321 Elm Street, City, State 12348',
    date_of_birth: '1996-05-14T00:00:00Z',
    seat_number: 'A004'
  },
  {
    id: 'student_005',
    first_name: 'Ibrahim',
    last_name: 'Khan',
    email: 'ibrahim.khan@example.com',
    phone: '+1234567898',
    address: '654 Maple Drive, City, State 12349',
    date_of_birth: '1994-09-30T00:00:00Z',
    seat_number: 'A005'
  },
  {
    id: 'student_006',
    first_name: 'Maryam',
    last_name: 'Ali',
    email: 'maryam.ali@example.com',
    phone: '+1234567800',
    address: '987 Cedar Lane, City, State 12350',
    date_of_birth: '1997-12-03T00:00:00Z',
    seat_number: 'A006'
  },
  {
    id: 'student_007',
    first_name: 'Yusuf',
    last_name: 'Rahman',
    email: 'yusuf.rahman@example.com',
    phone: '+1234567802',
    address: '147 Birch Court, City, State 12351',
    date_of_birth: '1993-04-18T00:00:00Z',
    seat_number: 'A007'
  },
  {
    id: 'student_008',
    first_name: 'Khadija',
    last_name: 'Salim',
    email: 'khadija.salim@example.com',
    phone: '+1234567804',
    address: '258 Willow Way, City, State 12352',
    date_of_birth: '1999-08-25T00:00:00Z',
    seat_number: 'A008'
  },
  {
    id: 'student_009',
    first_name: 'Ali',
    last_name: 'Hussain',
    email: 'ali.hussain@example.com',
    phone: '+1234567806',
    address: '369 Spruce Street, City, State 12353',
    date_of_birth: '1991-06-12T00:00:00Z',
    seat_number: 'A009'
  },
  {
    id: 'student_010',
    first_name: 'Zaynab',
    last_name: 'Omar',
    email: 'zaynab.omar@example.com',
    phone: '+1234567808',
    address: '741 Poplar Place, City, State 12354',
    date_of_birth: '1996-10-07T00:00:00Z',
    seat_number: 'A010'
  }
];

// Helpers to match app schema (first_name, last_name, date_of_birth required)
function splitName(full) {
  const parts = String(full).trim().split(/\s+/);
  if (parts.length === 1) return { first: parts[0], last: 'N/A' };
  const last = parts.pop();
  return { first: parts.join(' '), last };
}

function randomDob() {
  // Random date between 1995-01-01 and 2010-12-31
  const start = new Date('1995-01-01T00:00:00Z').getTime();
  const end = new Date('2010-12-31T23:59:59Z').getTime();
  const ts = Math.floor(Math.random() * (end - start + 1)) + start;
  return new Date(ts).toISOString();
}

async function addDummyStudents() {
  try {
    console.log('Signing in as admin...');
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email: testEmail,
      password: testPassword
    });

    if (authError) {
      console.error('Authentication failed:', authError.message);
      return;
    }

    console.log('✅ Admin signed in successfully');
    console.log('User ID:', authData.user.id);
    console.log('Email:', authData.user.email);

    console.log('\nAdding dummy students...');
    
    for (let i = 0; i < dummyStudents.length; i++) {
      const src = dummyStudents[i];
      const hasNames = !!(src.first_name && src.last_name);
      const split = hasNames ? { first: src.first_name, last: src.last_name } : splitName(src.name);
      const first = split.first;
      const last = split.last;
      const row = {
        id: src.id || randomUUID(),
        first_name: first,
        last_name: last,
        date_of_birth: src.date_of_birth || randomDob(),
        email: src.email,
        phone: src.phone || null,
        address: src.address || null,
        seat_number: src.seat_number || null,
      };

      console.log(`Adding student ${i + 1}/${dummyStudents.length}: ${first} ${last}`);

      const { data, error } = await supabase
        .from('students')
        .upsert(row, { onConflict: 'email' })
        .select('id, first_name, last_name');

      if (error) {
        console.error(`❌ Failed to add ${first} ${last}:`, error.message);
      } else if (data && data[0]) {
        console.log(`✅ Added ${data[0].first_name} ${data[0].last_name} (ID: ${data[0].id})`);
      } else {
        console.log(`ℹ️ Upserted ${first} ${last}`);
      }
      
      // Small delay to avoid overwhelming the database
      await new Promise(resolve => setTimeout(resolve, 100));
    }

    // Verify total count
    const { data: allStudents, error: countError } = await supabase
      .from('students')
      .select('id, first_name, last_name')
      .order('created_at', { ascending: false });

    if (countError) {
      console.error('❌ Failed to count students:', countError.message);
    } else {
      console.log(`\n📊 Total students in database: ${allStudents.length}`);
      console.log('Recent students:');
      allStudents.slice(0, 5).forEach((s, index) => {
        console.log(`  ${index + 1}. ${s.first_name} ${s.last_name} (ID: ${s.id})`);
      });
    }

    console.log('\n🔓 Signing out...');
    await supabase.auth.signOut();
    console.log('✅ Signed out successfully');
    
  } catch (error) {
    console.error('❌ Unexpected error:', error.message);
  }
}

addDummyStudents();