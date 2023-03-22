using System;
using System.Collections;
using System.Reflection;

namespace Serialize
{
	[AttributeUsage(.Types)]
	struct SerializableAttribute : Attribute, IOnTypeInit
	{
		const StringView[?] NO_SERIALIZE_MEMBERS = StringView[] ("mClassVData", "mDbgAllocInfo");

		[Comptime]
		bool IsSerializableField(FieldInfo field)
		{
			let type = field.FieldType;

			if (NO_SERIALIZE_MEMBERS.Contains(field.Name))
				return false;

			if (type.IsPointer)
				return false;

			if (field.GetCustomAttribute<SerializeFieldAttribute>() case .Ok(let attr))
			{
				if (!attr.Serialize)
					return false;
			}

			return true;
		}

		[Comptime]
		void IOnTypeInit.OnTypeInit(Type type, Self* prev)
		{
			Compiler.EmitAddInterface(type, typeof(ISerializable));

			if (type.IsEnum)
			{
				WriteSerializeForEnum(type);
				return;
			}

			int fieldCount = 0;
			for (let field in type.GetFields())
				if (IsSerializableField(field))
					fieldCount++;

			Compiler.EmitTypeBody(type,
				scope $"""
				public void Serialize<S>(S serializer)
					where S : Serialize.Implementation.ISerializer
				{{
					serializer.SerializeMapStart({fieldCount});

					switch (serializer.SerializeOrder)
					{{
					case .InOrder:
						{{
				""");

			WriteSerializeInOrder(type);

			Compiler.EmitTypeBody(type,
				scope $"""
						}}
					case .PrimitivesArraysMaps:
						{{
				""");

			WriteSerializePrimitivesArraysMaps(type);

			Compiler.EmitTypeBody(type,
				scope $"""
						}}
					case .MapsLast:
						{{
				""");

			WriteSerializeMapsLast(type);

			Compiler.EmitTypeBody(type,
				scope $"""
						}}
					}}

				""");
			

			String fieldList = scope .();
			bool f = true;
			for (let field in type.GetFields())
			{
				if (!IsSerializableField(field))
					continue;

				if (!f)
					fieldList.Append(", ");
				fieldList.AppendF("\"{}\"", field.Name);
				f = false;
			}

			Compiler.EmitTypeBody(type,
				scope $"""
				
					serializer.SerializeMapEnd();
				}}

				public static System.Result<Self> Deserialize<S>(S deserializer)
					where S : Serialize.Implementation.IDeserializer
				{{
					Self self = {(type.IsValueType ? "" : "new ")}Self();
					bool ok = false;
					{(type.IsValueType ? "" : "defer {{ if (!ok) delete self; }}\n")}
					System.Collections.List<StringView> fieldsLeft = scope .(){{ {fieldList} }};

					Try!(deserializer.DeserializeStructStart({fieldCount}));

					delegate Result<void, Serialize.FieldDeserializeError>(StringView) map_field = scope [&] (field) => {{
						switch (field)
						{{

				""");

			for (let field in type.GetFields())
			{
				if (!IsSerializableField(field))
					continue;

				String valueRef;
				if (field.FieldType.IsInteger)
				{
					String systemType = scope .()..Append(field.FieldType);
					systemType[0] = systemType[0].ToUpper;
					valueRef = scope:: $"(System.{systemType}*)&self.{field.Name}";
				}
				else
					valueRef = scope:: $"&self.{field.Name}";

				if (field.FieldType.IsNullable || field.FieldType.IsObject)
					Compiler.EmitTypeBody(type,
						scope $"""
								case "{field.Name}":
									if (!deserializer.DeserializeNull())
									{{
										let result = {field.FieldType}.Deserialize(deserializer);
										if (result case .Err)
											return .Err(.DeserializationError);
										self.{field.Name} = result.Get();
									}}
									fieldsLeft.Remove("{field.Name}");
									break;
	
						""");
				else
					Compiler.EmitTypeBody(type,
					scope $"""
							case "{field.Name}":
								let result = {field.FieldType}.Deserialize(deserializer);
								if (result case .Err)
									return .Err(.DeserializationError);
								self.{field.Name} = (.)result.Get();
								fieldsLeft.Remove("{field.Name}");
								break;

					""");
			}


			Compiler.EmitTypeBody(type,
				scope $"""
						default:
							return .Err(.UnknownField);
						}}

						return .Ok;
					}};

					bool firstField = true;
					for (int i in 0..<{fieldCount})
					{{
						Try!(deserializer.DeserializeStructField(map_field, fieldsLeft, firstField));
						firstField = false;
					}}


				""");

			for (let field in type.GetFields())
			{
				if (field.GetCustomAttribute<SerializeFieldAttribute>() case .Ok(let attr))
				{
					if (attr.Default != null)
					{
						Compiler.EmitTypeBody(type,
							scope $"""
								if (fieldsLeft.Contains("{field.Name}"))
									self.{field.Name} = {attr.Default}();


							""");
					}
					else if (attr.DefaultValue != null)
					{
						Compiler.EmitTypeBody(type,
							scope $"""
								if (fieldsLeft.Contains("{field.Name}"))
									self.{field.Name} = {attr.DefaultValue};


							""");
					}
				}
			}

			for (let field in type.GetFields())
			{
				if (field.GetCustomAttribute<SerializeFieldAttribute>() case .Ok(let attr))
				{
					if (attr.Optional)
					{
						Compiler.EmitTypeBody(type,
							scope $"""
								fieldsLeft.Remove("{field.Name}");

							""");
					}
				}
			}	

			Compiler.EmitTypeBody(type,
				scope $"""
					if (!fieldsLeft.IsEmpty)
					{{
						String message = new .();
						if (fieldsLeft.Count == 1)
							message.Append("Missing field ");
						else
							message.Append("Missing fields ");

						bool first = true;
						for (StringView field in fieldsLeft)
						{{
							if (!first)
								message.Append(", ");
							message.Append(field);
							first = false;
						}}

						message.Append(" on type {type.GetName(.. scope .())}");

						deserializer.SetError(new .(message, deserializer));
						return .Err;
					}}

					Try!(deserializer.DeserializeStructEnd());
					ok = true;
					return .Ok(self);
				}}
				""");
		}

		[Comptime]
		void WriteSerializeForField(Type type, FieldInfo field, ref String first)
		{
			if (!IsSerializableField(field))
				return;

			let serializeAttribute = field.GetCustomAttribute<SerializeFieldAttribute>();
			if (serializeAttribute case .Ok(let attr))
			{
				if (attr.NumberFormat != null)
					Compiler.EmitTypeBody(type,
						scope $"""
	
									serializer.NumberFormat = "{attr.NumberFormat}";
						""");
			}

			if (field.FieldType.IsNullable || field.FieldType.IsObject)
				Compiler.EmitTypeBody(type,
					scope $"""

								//if ({field.Name} == null) serializer.SerializeNull();
								/*else*/ serializer.SerializeMapEntry("{field.Name}", {field.Name}, {first});

					""");
			else
				Compiler.EmitTypeBody(type,
				scope $"""

							serializer.SerializeMapEntry("{field.Name}", {field.Name}, {first});

				""");

			if (serializeAttribute case .Ok(let attr))
			{
				if (attr.NumberFormat != null)
					Compiler.EmitTypeBody(type,
						scope $"""
									serializer.NumberFormat = "";

						""");
			}

			first = "false";
		}

		[Comptime]
		void WriteSerializeInOrder(Type type)
		{
			String first = "true";
			for (let field in type.GetFields())
			{
				WriteSerializeForField(type, field, ref first);
				first = "false";
			}
		}

		[Comptime]
		void WriteSerializePrimitivesArraysMaps(Type type)
		{
			String first = "true";
			List<StringView> primitives = scope .();
			List<StringView> arrays = scope .();
			List<StringView> maps = scope .();

			for (let field in type.GetFields())
			{
				if (IsPrimitive(field.FieldType))
					primitives.Add(field.Name);
				else if (IsListOrArray(field.FieldType))
					arrays.Add(field.Name);
				else
					maps.Add(field.Name);
			}

			for (let field in type.GetFields())
				if (primitives.Contains(field.Name))
					WriteSerializeForField(type, field, ref first);

			for (let field in type.GetFields())
				if (arrays.Contains(field.Name))
					WriteSerializeForField(type, field, ref first);

			for (let field in type.GetFields())
				if (maps.Contains(field.Name))
					WriteSerializeForField(type, field, ref first);
		}

		[Comptime]
		void WriteSerializeMapsLast(Type type)
		{
			String first = "true";
			List<StringView> maps = scope .();

			for (let field in type.GetFields())
			{
				if (IsPrimitive(field.FieldType) || IsListOrArray(field.FieldType))
					WriteSerializeForField(type, field, ref first);
				else
					maps.Add(field.Name);
			}

			for (let field in type.GetFields())
				if (maps.Contains(field.Name))
					WriteSerializeForField(type, field, ref first);
		}

		[Comptime]
		void WriteSerializeForEnum(Type type)
		{
			Compiler.EmitTypeBody(type,
				scope $"""
				public void Serialize<S>(S serializer)
					where S : Serialize.Implementation.ISerializer
				{{
					switch (this)
					{{

				""");

			for (let field in type.GetFields())
			{
				Compiler.EmitTypeBody(type,
					scope $"""
						case .{field.Name}: serializer.SerializeString("{field.Name}");

					""");
			}

			Compiler.EmitTypeBody(type,
				scope $"""
					}}
				}}

				public static Result<Self> Deserialize<D>(D deserializer)
					where D : Serialize.Implementation.IDeserializer
				{{
					let start = deserializer.Reader.Position + 1;
					let str = Try!(deserializer.DeserializeString());
					defer delete str;
					switch (str)
					{{

				""");

			for (let field in type.GetFields())
			{
				Compiler.EmitTypeBody(type,
					scope $"""
						case "{field.Name}": return .{field.Name};

					""");
			}


			Compiler.EmitTypeBody(type,
				scope $"""
					}}

					let end = deserializer.Reader.Position - 1;
					DeserializeError error = new .(new $"Unknown enum value '{{str}}'", deserializer, end - start, start);
					deserializer.SetError(error);
					return .Err;
				}}
				""");
		}

		[Comptime]
		bool IsPrimitive(Type type)
		{
			let generic = type as SpecializedGenericType;

			return
				type.IsPrimitive || type.IsEnum ||
				type == typeof(String) || type == typeof(DateTime) ||
				(generic != null &&
				generic.UnspecializedType == typeof(Nullable<>) &&
				IsPrimitive(generic.GetGenericArg(0)));
		}

		[Comptime]
		bool IsListOrArray(Type type)
		{
			return type.IsArray ||
				(type is SpecializedGenericType &&
				(type as SpecializedGenericType).UnspecializedType == typeof(List<>));
		}
	}

	struct SerializeFieldAttribute : Attribute, IOnFieldInit
	{
		public bool Serialize;

		public bool Optional
		{
			get => HasDefault || (_optional ?? false);
			set mut => _optional = value;
		}

		public String Default = null;
		public String DefaultValue = null;

		public String NumberFormat = null;

		public bool HasDefault => Default != null || DefaultValue != null;

		private Nullable<bool> _optional = null;

		public this(bool serialize = true)
		{
			Serialize = serialize;
		}

		[Comptime]
		public void OnFieldInit(FieldInfo fieldInfo, Self* prev)
		{
			let type = fieldInfo.FieldType;

			if (_optional.HasValue && !_optional.Value && HasDefault)
				Runtime.FatalError("Specifying a default value forces a field to be optional");

			if (NumberFormat != null && !IsNumber(type))
			{
				let generic = type as SpecializedGenericType;
				if (generic != null && generic.UnspecializedType == typeof(List<>))
				{
					if (!IsNumber(generic.GetGenericArg(0)))
						Runtime.FatalError("List must have numeric values to use NumberFormat");
				}
				else if (generic != null && generic.UnspecializedType == typeof(Dictionary<>))
				{
					if (!IsNumber(generic.GetGenericArg(1)))
						Runtime.FatalError("Dictionary must have numeric values to use NumberFormat");
				}
				else
					Runtime.FatalError(scope $"Field type is not a number: {!IsNumber(generic.GetGenericArg(0))}");
			}

			bool IsNumber(Type type) => type.IsInteger || type.IsFloatingPoint;
		}
	}
}